package model

import (
	"nft_backend/testutil"
	"testing"
)

func TestChainSyncCheckpointCRUD(t *testing.T) {
	db := testutil.NewTestDB(t)

	if err := db.AutoMigrate(&ChainSyncCheckpoint{}); err != nil {
		t.Fatalf("auto migrate checkpoint: %v", err)
	}
	// 1. Create：创建同步断点
	checkpoint := ChainSyncCheckpoint{
		ChainID:                11155111,
		ContractAddress:        "0xa11b8629fC9d16F6DdEa8fBa3921B27208160A26",
		LastProcessedBlock:     10880796,
		LastProcessedBlockHash: "0x1111111111111111111111111111111111111111111111111111111111111111",
		NextBlock:              10880797,
	}

	if err := db.Create(&checkpoint).Error; err != nil {
		t.Fatalf("create checkpoint: %v", err)
	}
	if checkpoint.ID == 0 {
		t.Fatal("expected checkpoint ID to be assigned")
	}

	// 2. Read：按“链 ID + 合约地址”查询
	var found ChainSyncCheckpoint
	err := db.
		Where("chain_id = ? AND contract_address = ?",
			11155111,
			"0xa11b8629fC9d16F6DdEa8fBa3921B27208160A26",
		).
		First(&found).Error
	if err != nil {
		t.Fatalf("find checkpoint: %v", err)
	}

	if found.NextBlock != 10880797 {
		t.Fatalf("NextBlock = %d, want %d", found.NextBlock, 10880797)
	}

	// 3. Update：模拟成功处理了几个新区块后推进游标
	err = db.Model(&ChainSyncCheckpoint{}).
		Where("id = ?", found.ID).
		Updates(map[string]any{
			"last_processed_block":      uint64(10880800),
			"last_processed_block_hash": "0x2222222222222222222222222222222222222222222222222222222222222222",
			"next_block":                uint64(10880801),
		}).Error
	if err != nil {
		t.Fatalf("update checkpoint: %v", err)
	}

	// 4. 再查询并验证更新结果
	var updated ChainSyncCheckpoint
	if err := db.First(&updated, found.ID).Error; err != nil {
		t.Fatalf("read updated checkpoint: %v", err)
	}

	if updated.LastProcessedBlock != 10880800 {
		t.Fatalf("LastProcessedBlock = %d, want %d",
			updated.LastProcessedBlock, 10880800)
	}
	if updated.NextBlock != 10880801 {
		t.Fatalf("NextBlock = %d, want %d", updated.NextBlock, 10880801)
	}
}

func TestChainSyncCheckpointRepeat(t *testing.T) {
	db := testutil.NewTestDB(t)
	if err := db.AutoMigrate(&ChainSyncCheckpoint{}); err != nil {
		t.Fatalf("auto migrate: %v", err)
	}
	checkpoint1 := ChainSyncCheckpoint{
		ChainID:                11155111,
		ContractAddress:        "0xa11b8629fC9d16F6DdEa8fBa3921B27208160A26",
		LastProcessedBlock:     10880796,
		LastProcessedBlockHash: "0x1111111111111111111111111111111111111111111111111111111111111111",
		NextBlock:              10880797,
	}
	checkpoint2 := ChainSyncCheckpoint{
		ChainID:                11155111,
		ContractAddress:        "0xa11b8629fC9d16F6DdEa8fBa3921B27208160A26",
		LastProcessedBlock:     10880797,
		LastProcessedBlockHash: "0x1111111111111111111111111211111111111111111111111111111111111111",
		NextBlock:              10880798,
	}
	if err := db.Create(&checkpoint1).Error; err != nil {
		t.Fatalf("create checkpoint1: %v", err)
	}
	if err := db.Create(&checkpoint2).Error; err == nil {
		t.Fatal("expected duplicate checkpoint insertion to fail, but it succeeded")
	}
}
