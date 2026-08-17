package repository

import (
	"nft_backend/model"

	"github.com/ethereum/go-ethereum/core/types"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

func BuildChainSyncCheckpoint(chainId uint64, contractAddress string, header *types.Header) (*model.ChainSyncCheckpoint, error) {
	return &model.ChainSyncCheckpoint{
		ChainID:                chainId,
		ContractAddress:        contractAddress,
		LastProcessedBlock:     uint64(header.Number.Int64()),
		NextBlock:              uint64(header.Number.Int64()) + 1,
		LastProcessedBlockHash: header.Hash().Hex(),
	}, nil
}

func SaveOrUpdateChainSyncCheckpoint(db *gorm.DB, checkpoint *model.ChainSyncCheckpoint) error {
	return db.Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "chain_id"}, {Name: "contract_address"}},
		DoUpdates: clause.AssignmentColumns([]string{"last_processed_block", "last_processed_block_hash", "next_block", "updated_at"}),
	}).Create(checkpoint).Error
}

func FindCheckpoint(db *gorm.DB, chainId uint64, contractAddress string) (*model.ChainSyncCheckpoint, error) {
	var checkpoint model.ChainSyncCheckpoint
	if err := db.Where("chain_id = ? and contract_address = ?", chainId, contractAddress).First(&checkpoint).Error; err != nil {
		return nil, err
	}
	return &checkpoint, nil
}
