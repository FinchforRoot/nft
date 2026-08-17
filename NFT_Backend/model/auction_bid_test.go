package model

import (
	"nft_backend/testutil"
	"testing"
)

// 验证一场拍卖可以有多条出价
func TestAuctionBidCreateMulti(t *testing.T) {
	db := testutil.NewTestDB(t)
	if err := db.AutoMigrate(&AuctionBid{}); err != nil {
		t.Fatalf("auto migrate checkpoint: %v", err)
	}
	auctionBid1 := AuctionBid{
		AuctionDBID:  1,
		ChainEventID: 1,
		Bidder:       "0x1234",
		BidUSDRaw:    "50000000000000000",
		AmountRaw:    "150000000",
		TokenAddress: "0x000000000000000000000000000000000001",
	}

	auctionBid2 := AuctionBid{
		AuctionDBID:  1,
		ChainEventID: 2,
		Bidder:       "0x1234567",
		BidUSDRaw:    "60000000000000000",
		AmountRaw:    "160000000",
		TokenAddress: "0x000000000000000000000000000000000001",
	}

	if err := db.Create(&auctionBid1).Error; err != nil {
		t.Fatalf("insert error.....")
	}
	if err := db.Create(&auctionBid2).Error; err != nil {
		t.Fatalf("same auction bid error...........")
	}

	// 查回这场拍卖（auction_db_id = 1）的全部出价，验证"一场拍卖可以有多条出价"
	var bids []AuctionBid
	if err := db.Where("auction_db_id = ?", 1).Find(&bids).Error; err != nil {
		t.Fatalf("find bids: %v", err)
	}
	if len(bids) != 2 {
		t.Fatalf("len(bids) = %d, want 2", len(bids))
	}
}

// 验证相同的 chain_event_id 不能重复插入（同一出价事件只投影一条记录）
func TestAuctionBidUniqueByEvent(t *testing.T) {
	db := testutil.NewTestDB(t)
	if err := db.AutoMigrate(&AuctionBid{}); err != nil {
		t.Fatalf("auto migrate auction_bid: %v", err)
	}

	bid1 := AuctionBid{
		AuctionDBID:  1,
		ChainEventID: 1, // 唯一键
		Bidder:       "0x1234",
		BidUSDRaw:    "50000000000000000",
		AmountRaw:    "150000000",
		TokenAddress: "0x000000000000000000000000000000000001",
	}
	if err := db.Create(&bid1).Error; err != nil {
		t.Fatalf("create bid1: %v", err)
	}

	// 第二条：chain_event_id 与 bid1 完全相同 → 必须因唯一索引失败
	bid2 := AuctionBid{
		AuctionDBID:  1,
		ChainEventID: 1, // ← 与 bid1 相同，触发唯一冲突
		Bidder:       "0x5678",
		BidUSDRaw:    "60000000000000000",
		AmountRaw:    "160000000",
		TokenAddress: "0x000000000000000000000000000000000001",
	}
	if err := db.Create(&bid2).Error; err == nil {
		t.Fatal("expected duplicate chain_event_id to fail, but it succeeded")
	}
}
