package chain

import (
	"fmt"

	"github.com/ethereum/go-ethereum/ethclient"
)

func NewRPCClient(rpcURL string) (*ethclient.Client, error) {
	client, err := ethclient.Dial(rpcURL)
	if err != nil {
		return nil, fmt.Errorf("connect rpc: %w", err)
	}
	return client, nil
}
