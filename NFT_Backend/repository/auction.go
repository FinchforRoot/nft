package repository

import (
	"errors"
	"math/big"
	"nft_backend/model"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"gorm.io/gorm"
)

type AuctionStats struct {
	TotalAuctions int64 `json:"total_auctions"`
	Ongoing       int64 `json:"ongoing"`
	Pending       int64 `json:"pending"`
	Ended         int64 `json:"ended"`
	NoBid         int64 `json:"no_bid"`
	Cancelled     int64 `json:"cancelled"`
	TotalBids     int64 `json:"total_bids"`
}

func BuildAuctionCreated(decoded map[string]any, chainId, createEventId uint64, contractAddress string, blockTime time.Time) (*model.Auction, error) {

	// 从decoded中提取各个字段
	auctionId, ok := decoded["auctionId"].(*big.Int)
	if !ok {
		return nil, errors.New("invalid auctionId")
	}
	seller, ok := decoded["seller"].(common.Address)
	if !ok {
		return nil, errors.New("invalid seller")
	}
	nftContract, ok := decoded["nftContract"].(common.Address)
	if !ok {
		return nil, errors.New("invalid nftContract")
	}
	tokenId, ok := decoded["tokenId"].(*big.Int)
	if !ok {
		return nil, errors.New("invalid tokenId")
	}
	startPrice, ok := decoded["startPrice"].(*big.Int)
	if !ok {
		return nil, errors.New("invalid startPrice")
	}
	startTime, ok := decoded["startTime"].(*big.Int)
	if !ok {
		return nil, errors.New("invalid startTime")
	}
	duration, ok := decoded["duration"].(*big.Int) // 单位：小时
	if !ok {
		return nil, errors.New("invalid duration")
	}

	// 计算开始时间和结束时间
	startTimestamp := startTime.Int64()
	durationSeconds := duration.Int64() * 3600 // 将小时转换为秒
	endTimestamp := startTimestamp + durationSeconds

	// 转换为time.Time
	startTimeObj := time.Unix(startTimestamp, 0)
	endTimeObj := time.Unix(endTimestamp, 0)

	chainStatus := "ongoing"
	if startTimeObj.After(blockTime) {
		chainStatus = "pending"
	}

	return &model.Auction{
		ChainID:          chainId,
		AuctionContract:  contractAddress,
		AuctionID:        auctionId.String(),
		Seller:           seller.Hex(),
		NFTContract:      nftContract.Hex(),
		TokenIDRaw:       tokenId.String(),
		StartPriceUSDRaw: startPrice.String(),
		StartTime:        startTimeObj,
		DurationSeconds:  uint64(durationSeconds),
		EndTime:          endTimeObj,
		ChainStatus:      chainStatus,
		CreatedEventID:   createEventId,
	}, nil
}

func UpdateHighestBid(db *gorm.DB, auctionDBID uint64, decoded map[string]any) error {
	bidder, ok := decoded["bidder"].(common.Address)
	if !ok {
		return errors.New("invalid bidder")
	}
	bid, ok := decoded["bid"].(*big.Int)
	if !ok {
		return errors.New("invalid bid")
	}
	bidAmount, ok := decoded["bidAmount"].(*big.Int)
	if !ok {
		return errors.New("invalid bidAmount")
	}
	tokenAddress, ok := decoded["tokenAddress"].(common.Address)
	if !ok {
		return errors.New("invalid tokenAddress")
	}

	if err := db.Model(&model.Auction{}).Where("id=?", auctionDBID).Updates(
		map[string]any{
			"highest_bid_usd_raw":    bid.String(),
			"highest_bidder":         bidder.Hex(),
			"highest_bid_amount_raw": bidAmount.String(),
			"bid_token_address":      tokenAddress.Hex(),
		}).Error; err != nil {
		return err
	}

	return nil
}

func MarkAuctionEnded(db *gorm.DB, auctionDBID uint64, decoded map[string]any, endEventId uint64) error {
	winner, ok := decoded["winner"].(common.Address)
	if !ok {
		return errors.New("invalid winner")
	}
	winningBid, ok := decoded["winningBid"].(*big.Int)
	if !ok {
		return errors.New("invalid winningBid")
	}
	tokenAddress, ok := decoded["tokenAddress"].(common.Address)
	if !ok {
		return errors.New("invalid tokenAddress")
	}
	tokenAmount, ok := decoded["tokenAmount"].(*big.Int)
	if !ok {
		return errors.New("invalid tokenAmount")
	}
	if err := db.Model(&model.Auction{}).Where("id =?", auctionDBID).Updates(
		map[string]any{
			"highest_bidder":         winner.Hex(),
			"ended_event_id":         endEventId,
			"highest_bid_usd_raw":    winningBid.String(),
			"bid_token_address":      tokenAddress.Hex(),
			"highest_bid_amount_raw": tokenAmount.String(),
			"chain_status":           "ended",
		}).Error; err != nil {
		return err
	}
	return nil
}

func MarkAuctionCancelled(db *gorm.DB, auctionDBID uint64) error {
	if err := db.Model(&model.Auction{}).Where("id=?", auctionDBID).Updates(
		map[string]any{
			"chain_status": "cancelled",
		}).Error; err != nil {
		return err
	}
	return nil
}

func FindAuctionByIdentity(db *gorm.DB, chainID uint64, contractAddress, auctionID string) (*model.Auction, error) {
	var auction model.Auction
	if err := db.Where("chain_id=? and auction_contract = ? and auction_id = ?", chainID, contractAddress, auctionID).First(&auction).Error; err != nil {
		return nil, err
	}
	return &auction, nil
}

func SaveAuction(db *gorm.DB, auction *model.Auction) error {
	return db.Create(&auction).Error
}

func ListAuctions(db *gorm.DB, status string, page, pageSize int) ([]model.Auction, int64, error) {
	// 条件先组装在一个 query 上（GORM 的链式调用：同一个 *gorm.DB 逐步加条件）
	query := db.Model(&model.Auction{})
	if status != "" {
		query = query.Where("chain_status = ?", status)
	}

	// 1. 先查总数（不带 Limit/Offset，count 的是全部符合条件的行）
	var total int64
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	// 2. 再查当前页数据
	var auctions []model.Auction
	err := query.Order("id DESC").Limit(pageSize).Offset((page - 1) * pageSize).Find(&auctions).Error
	if err != nil {
		return nil, 0, err
	}
	return auctions, total, nil
}

// ListBidsByAuction 查一场拍卖的出价历史，新的在前。
func ListBidsByAuction(db *gorm.DB, auctionDBID uint64) ([]model.AuctionBid, error) {
	var bids []model.AuctionBid
	err := db.Where("auction_db_id = ?", auctionDBID).Order("id DESC").Find(&bids).Error
	if err != nil {
		return nil, err
	}
	return bids, nil
}

// GetStats 按 chain_status 分组计数 + 出价总数。
// Group 查出来的是一行行 {chain_status, 数量}，扫描进临时结构再填到 AuctionStats。
func GetStats(db *gorm.DB) (*AuctionStats, error) {
	var rows []struct {
		ChainStatus string `gorm:"column:chain_status"`
		Count       int64  `gorm:"column:count"`
	}
	if err := db.Model(&model.Auction{}).
		Select("chain_status, COUNT(*) as count").
		Group("chain_status").
		Scan(&rows).Error; err != nil {
		return nil, err
	}

	stats := &AuctionStats{}
	for _, r := range rows {
		stats.TotalAuctions += r.Count
		switch r.ChainStatus {
		case "ongoing":
			stats.Ongoing = r.Count
		case "pending":
			stats.Pending = r.Count
		case "ended":
			stats.Ended = r.Count
		case "no_bid":
			stats.NoBid = r.Count
		case "cancelled":
			stats.Cancelled = r.Count
		}
	}

	// 出价总数单独 count
	if err := db.Model(&model.AuctionBid{}).Count(&stats.TotalBids).Error; err != nil {
		return nil, err
	}
	return stats, nil
}
