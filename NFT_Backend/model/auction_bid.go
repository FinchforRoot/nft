package model

import "time"

// 一条 NewHighestBid 事件投影出一条出价历史。
type AuctionBid struct {
	ID           uint64 `gorm:"primaryKey;comment:主键ID"`
	AuctionDBID  uint64 `gorm:"not null;index;comment:关联的拍卖记录ID【外键】"`
	ChainEventID uint64 `gorm:"not null;uniqueIndex;comment:链上事件ID【防重】"`

	// 出价信息
	Bidder       string `gorm:"size:42;not null;index;comment:出价人地址"`
	BidUSDRaw    string `gorm:"size:78;not null;comment:出价金额【USD 18位精度】"`
	AmountRaw    string `gorm:"size:78;not null;comment:出价代币数量【原始精度】"`
	TokenAddress string `gorm:"size:42;not null;comment:出价代币地址【0x0000000000000000000000000000000000000000为ETH】"`

	CreatedAt time.Time `gorm:"autoCreateTime;comment:入库时间"`
}
