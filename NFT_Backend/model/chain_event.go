package model

import "time"

// 一条链上日志对应一条原始事件记录。
type ChainEvent struct {
	ID uint64 `gorm:"primaryKey;comment:主键ID"`

	// 事件唯一标识（链ID + 合约地址 + 交易哈希 + 日志索引）
	ChainID         uint64 `gorm:"not null;uniqueIndex:uk_event_identity;index;comment:链ID"`
	ContractAddress string `gorm:"size:42;not null;uniqueIndex:uk_event_identity;index;comment:合约地址"`
	TxHash          string `gorm:"size:66;not null;uniqueIndex:uk_event_identity;comment:交易哈希"`
	LogIndex        uint   `gorm:"not null;uniqueIndex:uk_event_identity;comment:日志索引【交易内序号】"`

	// 区块信息
	BlockNumber uint64    `gorm:"not null;index;comment:区块高度"`
	BlockHash   string    `gorm:"size:66;not null;comment:区块哈希"`
	BlockTime   time.Time `gorm:"not null;comment:区块时间戳"`

	// 事件内容
	EventName string `gorm:"size:64;not null;index;comment:事件名称【如 AuctionCreated】"`
	Topic0    string `gorm:"size:66;not null;comment:事件签名哈希【topic[0]】"`
	RawData   string `gorm:"type:longtext;not null;comment:原始日志数据【ABI编码的hex】"`
	Decoded   string `gorm:"type:json;comment:已解码的JSON数据"`

	CreatedAt time.Time `gorm:"autoCreateTime;comment:入库时间"`
}
