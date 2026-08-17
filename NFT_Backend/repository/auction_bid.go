package repository

import (
	"errors"
	"math/big"
	"nft_backend/model"

	"github.com/ethereum/go-ethereum/common"
	"gorm.io/gorm"
)

func BuildAuctionBid(decoded map[string]any, auctionDBID, chainEventId uint64) (*model.AuctionBid, error) {
	bidder, ok := decoded["bidder"].(common.Address)
	if !ok {
		return nil, errors.New("invalid bidder")
	}
	bid, ok := decoded["bid"].(*big.Int)
	if !ok {
		return nil, errors.New("invalid bid")
	}
	bidAmount, ok := decoded["bidAmount"].(*big.Int)
	if !ok {
		return nil, errors.New("invalid bidAmount")
	}

	tokenAddress, ok := decoded["tokenAddress"].(common.Address)
	if !ok {
		return nil, errors.New("invalid tokenAddress")
	}

	return &model.AuctionBid{
		AuctionDBID:  auctionDBID,
		ChainEventID: chainEventId,
		Bidder:       bidder.Hex(),
		BidUSDRaw:    bid.String(),
		AmountRaw:    bidAmount.String(),
		TokenAddress: tokenAddress.Hex(),
	}, nil
}
func SaveAuctionBid(db *gorm.DB, auctionBid *model.AuctionBid) error {
	return db.Create(auctionBid).Error
}
