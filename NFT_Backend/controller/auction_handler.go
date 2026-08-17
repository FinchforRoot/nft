package controller

import (
	"errors"
	"net/http"
	"nft_backend/service"
	"nft_backend/utils"
	"strconv"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// AuctionHandler
type AuctionHandler struct {
	svc *service.AuctionQueryService
}

func NewAuctionHandler(svc *service.AuctionQueryService) *AuctionHandler {
	return &AuctionHandler{svc: svc}
}

// ListAuctions GET /api/auctions?status=ongoing&page=1&page_size=10
func (h *AuctionHandler) ListAuctions(c *gin.Context) {
	// status 可不传 = 查全部
	status := c.Query("status")

	// 页码：默认 1；传了但不是数字就回落默认值
	page, err := strconv.Atoi(c.Query("page"))
	if err != nil {
		page = 1
	}
	pageSize, err := strconv.Atoi(c.Query("page_size"))
	if err != nil {
		pageSize = 10
	}
	// 上限保护，防止 ?page_size=100000 一次拖库
	if pageSize > 100 {
		pageSize = 100
	}

	auctions, total, err := h.svc.ListAuctions(status, page, pageSize)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, gin.H{
		"list":      auctions,
		"total":     total,
		"page":      page,
		"page_size": pageSize,
	})
}

// ListBids GET /api/auctions/:auctionId/bids
func (h *AuctionHandler) ListBids(c *gin.Context) {
	auctionId := c.Param("auctionId")

	bids, err := h.svc.ListBids(auctionId)
	if err != nil {
		// 拍卖不存在是 404，其他是 500
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Error(c, http.StatusNotFound, "拍卖不存在")
			return
		}
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, gin.H{
		"list":  bids,
		"total": len(bids),
	})
}

// Stats GET /api/stats
func (h *AuctionHandler) Stats(c *gin.Context) {
	stats, err := h.svc.Stats()
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.Success(c, stats)
}
