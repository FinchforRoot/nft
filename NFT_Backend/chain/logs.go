package chain

import (
	"context"
	"fmt"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
)

func FetchAuctionLogs(client *ethclient.Client, contractAddress string, fromBlock, toBlock, batchSize int64) ([]types.Log, error) {
	addr := common.HexToAddress(contractAddress)
	var all []types.Log
	for start := fromBlock; start <= toBlock; start += batchSize {
		end := start + batchSize - 1
		if end > toBlock {
			end = toBlock
		}
		logs, err := client.FilterLogs(context.Background(), ethereum.FilterQuery{
			Addresses: []common.Address{addr},
			FromBlock: big.NewInt(start),
			ToBlock:   big.NewInt(end),
		})
		if err != nil {
			return nil, fmt.Errorf("fetch [%d,%d]: %w", start, end, err)
		}
		all = append(all, logs...)
		time.Sleep(500 * time.Millisecond)
	}
	return all, nil
}
