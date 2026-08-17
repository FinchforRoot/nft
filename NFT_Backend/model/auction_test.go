package model

import (
	"nft_backend/testutil"
	"testing"
	"time"
)

// 测试创建
func TestAuctionCreate(t *testing.T) {
	db := testutil.NewTestDB(t)
	if err := db.AutoMigrate(&Auction{}); err != nil {
		t.Fatalf("auto migrate checkpoint: %v", err)
	}

	auction := Auction{
		ChainID:         11155111,
		AuctionContract: "0xa11b8629fC9d16F6DdEa8fBa3921B27208160A26",
		AuctionID:       "1",

		Seller:      "0x1234567890abcdef1234567890abcdef12345678",
		NFTContract: "0xabcdef1234567890abcdef1234567890abcdef12",
		TokenIDRaw:  "123",

		StartPriceUSDRaw: "1000000000000000000",
		StartTime:        time.Date(2026, 8, 1, 12, 0, 0, 0, time.UTC),
		DurationSeconds:  86400, // 1天 = 86400秒
		EndTime:          time.Date(2026, 8, 2, 12, 0, 0, 0, time.UTC),

		ChainStatus:     "pending",
		BidTokenAddress: "0x0000000000000000000000000000", // 零地址表示原生代币

		CreatedEventID: 1,
		EndedEventID:   nil, // 拍卖还没结束，所以是 nil
	}

	if err := db.Create(&auction).Error; err != nil {
		t.Fatalf("create auction failed.............")
	}

	var found Auction
	if err := db.Where("chain_id = ? and auction_id = ?", 11155111, 1).First(&found).Error; err != nil {
		t.Fatalf("select auction info failed................")
	}
	if found.ChainStatus != "pending" {
		t.Fatalf("chainstatus not right")
	}
	if found.HighestBidder != "" {
		t.Fatalf("HighestBidder cant be set")
	}
	if found.EndedEventID != nil {
		t.Fatalf("EndedEventID cant be set")
	}

}

func TestAuctionStatusTransition(t *testing.T) {
	db := testutil.NewTestDB(t)
	if err := db.AutoMigrate(&Auction{}); err != nil {
		t.Fatalf("auto migrate checkpoint: %v", err)
	}

	// 1. 建一场 pending 拍卖（复用方法一的数据）
	auction := Auction{
		ChainID:         11155111,
		AuctionContract: "0xa11b8629fC9d16F6DdEa8fBa3921B27208160A26",
		AuctionID:       "1",

		Seller:      "0x1234567890abcdef1234567890abcdef12345678",
		NFTContract: "0xabcdef1234567890abcdef1234567890abcdef12",
		TokenIDRaw:  "123",

		StartPriceUSDRaw: "1000000000000000000",
		StartTime:        time.Date(2026, 8, 1, 12, 0, 0, 0, time.UTC),
		DurationSeconds:  86400, // 1天 = 86400秒
		EndTime:          time.Date(2026, 8, 2, 12, 0, 0, 0, time.UTC),

		ChainStatus:     "pending",
		BidTokenAddress: "0x0000000000000000000000000000", // 零地址表示原生代币

		CreatedEventID: 1,
		EndedEventID:   nil, // 拍卖还没结束，所以是 nil
	}
	db.Create(&auction)

	// 2. 有人出价 → ongoing
	db.Model(&Auction{}).Where("id = ?", auction.ID).Updates(map[string]any{
		"chain_status":           "ongoing",
		"highest_bidder":         "0x123",
		"highest_bid_usd_raw":    "2000000000000000000",
		"highest_bid_amount_raw": "2000000000000000000",
	})
	// ← First 查回，断言 status=="ongoing"、highest_bidder 是你填的那个
	var found Auction
	if err := db.Where("id = ?", 1).First(&found).Error; err != nil {
		t.Fatalf("select auction info failed................")
	}
	if found.ChainStatus != "ongoing" {
		t.Fatalf("chainstatus not right")
	}
	if found.HighestBidder != "0x123" {
		t.Fatalf("highest_bidder not right")
	}
	// 3. 结束 → ended
	db.Model(&Auction{}).Where("id = ?", auction.ID).Updates(map[string]any{
		"chain_status":   "ended",
		"ended_event_id": 2,
	})
	// ← First 查回，断言 status=="ended"、ended_event_id 指向 2
	var found2 Auction
	if err := db.Where("id = ?", 1).First(&found2).Error; err != nil {
		t.Fatalf("select auction info failed................")
	}
	if found2.ChainStatus != "ended" {
		t.Fatalf("chainstatus not right")
	}
	if found2.EndedEventID == nil || *found2.EndedEventID != 2 {
		t.Fatalf("ended_event_id not right")
	}
}

func TestAuctionUnique(t *testing.T) {
	db := testutil.NewTestDB(t)
	if err := db.AutoMigrate(&Auction{}); err != nil {
		t.Fatalf("auto migrate checkpoint: %v", err)
	}
	auction := Auction{
		ChainID:         11155111,
		AuctionContract: "0xa11b8629fC9d16F6DdEa8fBa3921B27208160A26",
		AuctionID:       "1",

		Seller:      "0x1234567890abcdef1234567890abcdef12345678",
		NFTContract: "0xabcdef1234567890abcdef1234567890abcdef12",
		TokenIDRaw:  "123",

		StartPriceUSDRaw: "1000000000000000000",
		StartTime:        time.Date(2026, 8, 1, 12, 0, 0, 0, time.UTC),
		DurationSeconds:  86400, // 1天 = 86400秒
		EndTime:          time.Date(2026, 8, 2, 12, 0, 0, 0, time.UTC),

		ChainStatus:     "pending",
		BidTokenAddress: "0x0000000000000000000000000000", // 零地址表示原生代币

		CreatedEventID: 1,
		EndedEventID:   nil, // 拍卖还没结束，所以是 nil
	}
	if err := db.Create(&auction).Error; err != nil {
		t.Fatalf("create auction failed.............")
	}
	auction2 := Auction{
		ChainID:         11155111,
		AuctionContract: "0xa11b8629fC9d16F6DdEa8fBa3921B27208160A26",
		AuctionID:       "1",

		Seller:      "0x1234567",
		NFTContract: "0xabcdef",
		TokenIDRaw:  "123",

		StartPriceUSDRaw: "1000000000000000000",
		StartTime:        time.Date(2026, 8, 1, 12, 0, 0, 0, time.UTC),
		DurationSeconds:  86400, // 1天 = 86400秒
		EndTime:          time.Date(2026, 8, 2, 12, 0, 0, 0, time.UTC),

		ChainStatus:     "pending",
		BidTokenAddress: "0x0000000000000000000000000000", // 零地址表示原生代币

		CreatedEventID: 1,
		EndedEventID:   nil, // 拍卖还没结束，所以是 nil
	}
	if err := db.Create(&auction2).Error; err == nil {
		t.Fatalf("auction2 should not be created.............")
	}
	auction3 := Auction{
		ChainID:         11155111,
		AuctionContract: "0xa11b8629fC9d16F6DdEa8fBa3921B27208160A26",
		AuctionID:       "2",

		Seller:      "0x1234567",
		NFTContract: "0xabcdef",
		TokenIDRaw:  "123",

		StartPriceUSDRaw: "1000000000000000000",
		StartTime:        time.Date(2026, 8, 1, 12, 0, 0, 0, time.UTC),
		DurationSeconds:  86400, // 1天 = 86400秒
		EndTime:          time.Date(2026, 8, 2, 12, 0, 0, 0, time.UTC),

		ChainStatus:     "pending",
		BidTokenAddress: "0x0000000000000000000000000000", // 零地址表示原生代币

		CreatedEventID: 3,
		EndedEventID:   nil, // 拍卖还没结束，所以是 nil
	}
	if err := db.Create(&auction3).Error; err != nil {
		t.Fatalf("auction3 create failed.............")
	}
}
