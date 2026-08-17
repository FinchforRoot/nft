package service

import (
	"nft_backend/model"
	"nft_backend/repository"

	"gorm.io/gorm"
)

// AuctionQueryService 查询用例：handler 调它，它调 repository。
// 和 lesson-03 的 UserService 一样：struct 持有依赖，构造器注入。
//
// chainId + contractAddress 一起注入：URL 里的 auctionId 只是合约内编号，
// 不同合约都会从 0 开始编号，必须配成三元组才能唯一定位一场拍卖。
type AuctionQueryService struct {
	db              *gorm.DB
	chainId         uint64
	contractAddress string
}

func NewAuctionQueryService(db *gorm.DB, chainId uint64, contractAddress string) *AuctionQueryService {
	return &AuctionQueryService{db: db, chainId: chainId, contractAddress: contractAddress}
}

// ListAuctions 分页查拍卖列表，返回 列表 + 总数（总数给前端算总页数用）。
func (s *AuctionQueryService) ListAuctions(status string, page, pageSize int) ([]model.Auction, int64, error) {
	return repository.ListAuctions(s.db, status, page, pageSize)
}

// ListBids 先按三元组找到拍卖（不存在返回 ErrRecordNotFound，handler 转 404），
// 再查它的出价历史。
func (s *AuctionQueryService) ListBids(auctionId string) ([]model.AuctionBid, error) {
	auction, err := repository.FindAuctionByIdentity(s.db, s.chainId, s.contractAddress, auctionId)
	if err != nil {
		return nil, err
	}
	return repository.ListBidsByAuction(s.db, auction.ID)
}

// Stats 平台统计：总拍卖数 / 各状态数 / 总出价数。
func (s *AuctionQueryService) Stats() (*repository.AuctionStats, error) {
	return repository.GetStats(s.db)
}
