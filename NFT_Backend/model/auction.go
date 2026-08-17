package model

import "time"

// 一条 AuctionCreated 事件投影出一场拍卖的当前状态。
type Auction struct {
	ID uint64 `gorm:"primaryKey;comment:主键ID"`

	ChainID         uint64 `gorm:"not null;uniqueIndex:uk_auction_identity;comment:链ID"`
	AuctionContract string `gorm:"size:42;not null;uniqueIndex:uk_auction_identity;comment:拍卖所合约地址"`
	AuctionID       string `gorm:"size:78;not null;uniqueIndex:uk_auction_identity;comment:拍卖ID"`

	Seller      string `gorm:"size:42;not null;index;comment:卖家地址"`
	NFTContract string `gorm:"size:42;not null;index;comment:NFT合约地址"`
	TokenIDRaw  string `gorm:"size:78;not null;comment:NFTID"`

	StartPriceUSDRaw string    `gorm:"size:78;not null;comment:起拍价"`
	StartTime        time.Time `gorm:"not null;index;comment:拍卖开始时间"`
	DurationSeconds  uint64    `gorm:"not null;comment:持续时间"`
	EndTime          time.Time `gorm:"not null;index;comment:结束时间"`

	ChainStatus         string `gorm:"size:16;not null;index;comment:链上拍卖的状态"`
	HighestBidUSDRaw    string `gorm:"size:78;comment:最高出价金额【USD】"`
	HighestBidder       string `gorm:"size:42;comment:出价最高的买家地址"`
	HighestBidAmountRaw string `gorm:"size:78;comment:当前最新的出价代币数量"`
	BidTokenAddress     string `gorm:"size:42;not null;comment:代币地址【0x0是ETH】"`

	CreatedEventID uint64  `gorm:"not null;uniqueIndex;comment:事件开始ID"`
	EndedEventID   *uint64 `gorm:"uniqueIndex;comment:事件结束ID"`

	CreatedAt time.Time `gorm:"autoCreateTime;comment:创建时间"`
	UpdatedAt time.Time `gorm:"autoUpdateTime;comment:更新时间"`
}
