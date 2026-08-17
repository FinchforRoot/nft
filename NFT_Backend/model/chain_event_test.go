package model

import (
	"nft_backend/testutil"
	"testing"
	"time"
)

func TestChainEventCreateAndRead(t *testing.T) {
	db := testutil.NewTestDB(t)
	if err := db.AutoMigrate(&ChainEvent{}); err != nil {
		t.Fatalf("auto migrate checkpoint: %v", err)
	}
	chainEvent1 := ChainEvent{
		ChainID:         11155111,
		ContractAddress: "0xa11b8629fC9d16F6DdEa8fBa3921B27208160A26",
		TxHash:          "0xtxtxtxtxtxtx",
		LogIndex:        1,
		EventName:       "create",
		BlockNumber:     115500,
		BlockHash:       "blockhash",
		BlockTime:       time.Date(2025, 1, 15, 12, 30, 0, 0, time.UTC),
		Topic0:          "0x11111111111111111111111111111111111111",
		RawData:         "0x000000000000000000000000001",
		Decoded: `{
        "creator": "0x1234...",
        "tokenId": "1",
        "name": "MyNFT",
        "symbol": "MNFT"
    	}`,
	}
	if err := db.Create(&chainEvent1).Error; err != nil {
		t.Fatalf("create chainevent failed...")
	}

	chainEvent2 := ChainEvent{
		ChainID:         11155111,
		ContractAddress: "0xa11b8629fC9d16F6DdEa8fBa3921B27208160A26",
		TxHash:          "0xtxtxtxtxtxtx",
		LogIndex:        1,
		EventName:       "create",
		BlockNumber:     115500,
		BlockHash:       "blockhash",
		BlockTime:       time.Date(2025, 1, 15, 12, 30, 0, 0, time.UTC),
		Topic0:          "0x11111111111111111111111111111111111111",
		RawData:         "0x000000000000000000000000001",
		Decoded: `{
        "creator": "0x1234...",
        "tokenId": "1",
        "name": "MyNFT",
        "symbol": "MNFT"
    	}`,
	}
	if err := db.Create(&chainEvent2).Error; err == nil {
		t.Fatalf("index check failed............")
	}
	chainEvent3 := ChainEvent{
		ChainID:         11155111,
		ContractAddress: "0xa11b8629fC9d16F6DdEa8fBa3921B27208160A26",
		TxHash:          "0xttttttttttt",
		LogIndex:        2,
		EventName:       "create",
		BlockNumber:     115500,
		BlockHash:       "blockhash",
		BlockTime:       time.Date(2025, 1, 15, 12, 30, 0, 0, time.UTC),
		Topic0:          "0x11111111111111111111111111111111111111",
		RawData:         "0x000000000000000000000000001",
		Decoded: `{
        "creator": "0x1234...",
        "tokenId": "1",
        "name": "MyNFT",
        "symbol": "MNFT"
    	}`,
	}
	if err := db.Create(&chainEvent3).Error; err != nil {
		t.Fatalf("test failed.................%v", err)
	}

}
