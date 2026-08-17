package chain

import (
	_ "embed"
	"fmt"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/abi"
)

//go:embed abi/NftAuctionV3.json
var nftAuctionABIJSON []byte

func MustLoadNftAuctionABI() abi.ABI {
	parsed, err := abi.JSON(strings.NewReader(string(nftAuctionABIJSON)))
	if err != nil {
		panic(fmt.Sprintf("load abi: %v", err))
	}
	return parsed
}
