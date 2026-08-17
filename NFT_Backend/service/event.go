package service

import (
	"errors"
	"math/big"
	"nft_backend/model"
	"nft_backend/repository"

	"gorm.io/gorm"
)

// ApplyEvent 把一条链上事件投影到业务表（auctions / auction_bids）。
//
// chainEvent：已经写进 chain_events 的记录（用它的 ID 做外键，EventName 决定走哪个分支）。
// decoded：ABI 解码后的字段 map。必须是 main.go 里 DecodeLogs 返回的 fields 原样传进来——
//
//	不要从 chainEvent.Decoded（JSON 字符串）反序列化，否则大整数会变 float64，
//	repository 里的 (*big.Int) 断言会失败。
func ApplyEvent(db *gorm.DB, chainEvent *model.ChainEvent, decoded map[string]any) error {
	switch chainEvent.EventName {

	case "AuctionCreated":
		// 创建拍卖：组装 + 入库。CreatedEventID = 这条 chain_events 的主键 ID。
		auction, err := repository.BuildAuctionCreated(
			decoded, chainEvent.ChainID, chainEvent.ID, chainEvent.ContractAddress, chainEvent.BlockTime,
		)
		if err != nil {
			return err
		}
		return repository.SaveAuction(db, auction)

	case "NewHighestBid":
		// 出价：既要写 auction_bids，又要更新 auctions 的最高出价。
		auction, err := findAuctionByEvent(db, decoded, chainEvent)
		if err != nil {
			return err
		}
		// 写一条出价记录（ChainEventID = chainEvent.ID）
		bid, err := repository.BuildAuctionBid(decoded, auction.ID, chainEvent.ID)
		if err != nil {
			return err
		}
		if err := repository.SaveAuctionBid(db, bid); err != nil {
			return err
		}
		// 2) 更新 auctions 的最高出价 / 最高出价人 / 代币地址
		return repository.UpdateHighestBid(db, auction.ID, decoded)

	case "AuctionEnded":
		// 结束拍卖：改状态 ended + 回填 EndedEventID，并同步最终成交数据。
		auction, err := findAuctionByEvent(db, decoded, chainEvent)
		if err != nil {
			return err
		}
		return repository.MarkAuctionEnded(db, auction.ID, decoded, chainEvent.ID)

	case "AuctionCancelled":
		// 取消拍卖：改状态 cancelled。
		auction, err := findAuctionByEvent(db, decoded, chainEvent)
		if err != nil {
			return err
		}
		return repository.MarkAuctionCancelled(db, auction.ID)

	default:
		// 框架事件（Upgraded/Initialized 等）和非业务事件忽略。
		// 正常它们在 DecodeLogs 阶段就因“未知事件”被跳过了，这里兜底。
		return nil
	}
}

// findAuctionByEvent 从事件提取合约 auctionId（indexed uint256 → *big.Int），
// 用三元组（chainID + 合约地址 + auctionId）查出 auctions 记录，拿到内部主键 ID。
// NewHighestBid / AuctionEnded / AuctionCancelled 都需要它来定位记录。
func findAuctionByEvent(db *gorm.DB, decoded map[string]any, chainEvent *model.ChainEvent) (*model.Auction, error) {
	auctionID, ok := decoded["auctionId"].(*big.Int)
	if !ok {
		return nil, errors.New("invalid auctionId")
	}
	return repository.FindAuctionByIdentity(db, chainEvent.ChainID, chainEvent.ContractAddress, auctionID.String())
}
