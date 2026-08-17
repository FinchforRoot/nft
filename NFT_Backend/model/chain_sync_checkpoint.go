package model

import "time"

// 一个“链 + 合约”的同步断点。
type ChainSyncCheckpoint struct {
	ID uint64 `gorm:"primaryKey;comment:主键ID"`

	// 同步目标标识
	ChainID         uint64 `gorm:"not null;uniqueIndex:uk_checkpoint_chain_contract;comment:链ID【如 11155111=Sepolia】"`
	ContractAddress string `gorm:"size:42;not null;uniqueIndex:uk_checkpoint_chain_contract;comment:监听的合约地址"`

	// 同步进度
	LastProcessedBlock     uint64 `gorm:"not null;comment:最后处理的区块高度"`
	LastProcessedBlockHash string `gorm:"size:66;not null;comment:最后处理的区块哈希【防重组】"`
	NextBlock              uint64 `gorm:"not null;comment:下一次同步的起始区块"`

	CreatedAt time.Time `gorm:"autoCreateTime;comment:首次创建时间"`
	UpdatedAt time.Time `gorm:"autoUpdateTime;comment:最后更新时间"`
}
