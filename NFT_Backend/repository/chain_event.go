package repository

import (
	"encoding/json"
	"fmt"
	"nft_backend/model"
	"time"

	"github.com/ethereum/go-ethereum/core/types"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// 构建链事件对象
func BuildChainEvent(chainId uint64, log types.Log, blockTime time.Time, eventName string, decoded map[string]any) (*model.ChainEvent, error) {
	decodedJSON, err := json.Marshal(decoded)
	if err != nil {
		return nil, err
	}
	return &model.ChainEvent{
		ChainID:         chainId,
		ContractAddress: log.Address.Hex(),
		TxHash:          log.TxHash.Hex(),
		LogIndex:        log.Index,
		BlockNumber:     log.BlockNumber,
		BlockHash:       log.BlockHash.Hex(),
		BlockTime:       blockTime,
		EventName:       eventName,
		Topic0:          log.Topics[0].Hex(),
		Decoded:         string(decodedJSON),
		RawData:         fmt.Sprintf("0x%x", log.Data),
	}, nil
}

// SaveChainEvent 插入一条链上事件，靠唯一索引 (chain_id+contract_address+tx_hash+log_index) 去重。
// 返回受影响行数：1 = 新插入；0 = 已存在（重复事件）。
func SaveChainEvent(db *gorm.DB, chainEvent *model.ChainEvent) (int64, error) {
	result := db.Clauses(clause.OnConflict{DoNothing: true}).Create(chainEvent)
	return result.RowsAffected, result.Error
}
