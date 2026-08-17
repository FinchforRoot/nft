package controller

import (
	"nft_backend/service"
	"nft_backend/utils"

	"github.com/gin-gonic/gin"
)

// NewRouter 组装路由。svc 由 main 传入（依赖注入）。
func NewRouter(svc *service.AuctionQueryService) *gin.Engine {
	r := gin.Default()

	// 健康检查
	r.GET("/health", func(c *gin.Context) {
		utils.Success(c, gin.H{"status": "ok"})
	})

	api := r.Group("/api")
	{
		api.GET("/auctions", NewAuctionHandler(svc).ListAuctions)
		api.GET("/auctions/:auctionId/bids", NewAuctionHandler(svc).ListBids)
		api.GET("/stats", NewAuctionHandler(svc).Stats)
	}

	return r
}
