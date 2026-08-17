package main

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"nft_backend/chain"
	"nft_backend/config"
	"nft_backend/controller"
	"nft_backend/model"
	"nft_backend/repository"
	"nft_backend/service"
	"os"
	"strconv"
	"time"

	"github.com/ethereum/go-ethereum/ethclient"
	"gorm.io/gorm"
)

/* 连数据库 → 连链 → 读 checkpoint
   → 哈希对不上？清三张表，从头同步
   → 哈希对得上？从 next_block 接着同步
   → 拉 logs → 一个事务里：存事件 → 投影 → 推 checkpoint
   → 结束
*/
func main() {
	db, err := config.NewMySQLDB()
	if err != nil {
		panic(err)
	}
	if err := db.AutoMigrate(
		&model.Auction{},
		&model.AuctionBid{},
		&model.ChainEvent{},
		&model.ChainSyncCheckpoint{},
	); err != nil {
		panic(fmt.Errorf("执行数据库migrate时发生了error %s", err))
	}
	println("migrate done")
	client, err := chain.NewRPCClient(os.Getenv("SEPOLIA_RPC_URL"))
	if err != nil {
		panic(err)
	}
	chainIdBig, err := client.ChainID(context.Background())
	if err != nil {
		panic(err)
	}
	chainId := chainIdBig.Uint64()
	proxy_address := os.Getenv("AUCTION_PROXY_ADDRESS")

	go func() {
		// 先立刻跑一次，然后每30秒监听一次
		startWatcher(db, client, proxy_address, chainId)
		ticker := time.NewTicker(30 * time.Second)
		for range ticker.C {
			startWatcher(db, client, proxy_address, chainId)
		}
	}()
	auctionService := service.NewAuctionQueryService(db, chainId, proxy_address)
	r := controller.NewRouter(auctionService)
	if err := r.Run(":8080"); err != nil {
		panic(err)
	}
}

func startWatcher(db *gorm.DB, client *ethclient.Client, proxy_address string, chainId uint64) {
	header, err := client.HeaderByNumber(context.Background(), nil)
	if err != nil {
		panic(err)
	}
	fmt.Println("sepolia 当前区块：", header.Number)
	// 查同步进度：查不到（ErrRecordNotFound）= 首次运行，属正常情况，放行
	checkpoint, err := repository.FindCheckpoint(db, chainId, proxy_address)
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		panic(err)
	}
	// 首次：从部署区块（环境变量）全量拉；有进度：从 next_block 增量拉
	start, err := strconv.ParseInt(os.Getenv("CONTRACT_BLOCK_NUMBER"), 10, 64)
	if err != nil {
		panic(fmt.Sprintf("CONTRACT_BLOCK_NUMBER not set: %v", err))
	}
	if checkpoint != nil {
		lastHeader, err := client.HeaderByNumber(context.Background(), big.NewInt(int64(checkpoint.LastProcessedBlock)))
		if err != nil || lastHeader == nil {
			fmt.Println("拿不到上次处理区块的头，本轮跳过:", err)
			return
		}
		lastHash := lastHeader.Hash().Hex()
		if lastHash != checkpoint.LastProcessedBlockHash {
			fmt.Println("检测到 reorg,清空业务表,从部署区块全量重建")
			// 将涉及业务的三个表全部清空，从最开始合约部署的那个区块开始同步
			if err := db.Transaction(func(tx *gorm.DB) error {
				if err := tx.Where("1=1").Delete(&model.AuctionBid{}).Error; err != nil {
					return err
				}
				if err := tx.Where("1=1").Delete(&model.Auction{}).Error; err != nil {
					return err
				}
				if err := tx.Where("1=1").Delete(&model.ChainEvent{}).Error; err != nil {
					return err
				}
				return nil
			}); err != nil {
				fmt.Println("清空业务表失败，本轮跳过，下轮重试:", err)
				return
			}
		} else {
			start = int64(checkpoint.NextBlock)
		}
	}
	end := header.Number.Int64() - 10
	if start > end {
		fmt.Println("已追到安全区块，本轮跳过")
		return
	}
	logs, err := chain.FetchAuctionLogs(client, proxy_address, start, end, 2000)
	if err != nil {
		panic(err)
	}
	fmt.Println("日志总数：", len(logs))
	parseABI := chain.MustLoadNftAuctionABI()
	// 将区块信息缓存起来
	blockTimeCache := map[uint64]time.Time{}
	err = db.Transaction(func(tx *gorm.DB) error {
		for _, l := range logs {
			name, fields, err := chain.DecodeLogs(parseABI, l)
			if err != nil {
				fmt.Println(err)
				continue
			}
			bt, ok := blockTimeCache[l.BlockNumber]
			if !ok {
				h, err := client.HeaderByNumber(context.Background(), big.NewInt(int64(l.BlockNumber)))
				if err != nil {
					return err
				}
				bt = time.Unix(int64(h.Time), 0).UTC()
				blockTimeCache[l.BlockNumber] = bt
			}
			chainEvent, err := repository.BuildChainEvent(chainId, l, bt, name, fields)
			if err != nil {
				fmt.Println(err)
				continue
			}
			fmt.Printf("事件=%s 字段=%+v\n", name, fields)
			rowsAffected, err := repository.SaveChainEvent(tx, chainEvent)
			if err != nil {
				fmt.Println(err)
				return err
			}
			if rowsAffected == 0 {
				fmt.Printf("事件 %s 已存在，跳过\n", name)
				continue
			}
			// 新事件才投影（重复事件之前已投影过，不重复投影）
			if err := service.ApplyEvent(tx, chainEvent, fields); err != nil {
				fmt.Println("投影失败:", err)
				return err
			}
		}
		endHeader, err := client.HeaderByNumber(context.Background(), big.NewInt(end))
		if err != nil {
			return err // 查不到就不推进，回滚
		}

		cp := model.ChainSyncCheckpoint{
			ChainID:                chainId,
			ContractAddress:        proxy_address,
			LastProcessedBlock:     uint64(end),
			LastProcessedBlockHash: endHeader.Hash().Hex(),
			NextBlock:              uint64(end) + 1,
		}
		// 所有事件处理完，才推进 checkpoint。
		if err := repository.SaveOrUpdateChainSyncCheckpoint(tx, &cp); err != nil {
			fmt.Println("推进 checkpoint 失败:", err)
			return err
		} else {
			fmt.Println("checkpoint 推进到区块:", end+1)
			return nil
		}
	})
	if err != nil {
		fmt.Println("本轮同步失败已回滚，下次重拉这段:", err)
	}

}
