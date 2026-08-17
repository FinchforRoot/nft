package chain

import (
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
)

// 把一条日志解码成  事件、字段map
func DecodeLogs(parsedABI abi.ABI, l types.Log) (string, map[string]any, error) {
	if len(l.Topics) == 0 {
		return "", nil, fmt.Errorf("no topics")
	}
	// 获取事件名和topic的key以及对应的value
	var eventName string
	var event abi.Event
	for name, ev := range parsedABI.Events {
		sigHash := crypto.Keccak256Hash([]byte(ev.Sig))
		if sigHash == l.Topics[0] {
			eventName = name
			event = ev
			break
		}
	}
	if eventName == "" {
		return "", nil, fmt.Errorf("未知事件: %s", l.Topics[0].Hex())
	}

	// 用于存储这个事件的入参和对应的值
	fields := map[string]any{}
	// 解析indexed参数
	indexIdx := 0
	for _, arg := range event.Inputs {
		if !arg.Indexed {
			continue
		}
		topicPos := 1 + indexIdx
		indexIdx++
		// 如果topic位置超出范围，让程序继续运行不要报错
		if topicPos > len(l.Topics) {
			continue
		}
		topic := l.Topics[topicPos]
		switch arg.Type.T {
		case abi.AddressTy:
			fields[arg.Name] = common.BytesToAddress(topic.Bytes())
		case abi.IntTy, abi.UintTy:
			fields[arg.Name] = new(big.Int).SetBytes(topic.Bytes())
		case abi.BoolTy:
			fields[arg.Name] = topic[31] != 0
		default:
			fields[arg.Name] = topic.Hex()
		}
	}
	// 解析non-indexed参数
	if len(l.Data) > 0 {
		values, err := parsedABI.Unpack(eventName, l.Data)
		if err != nil {
			return eventName, fields, fmt.Errorf("unpack data: %w", err)
		}
		nonIdx := 0
		for _, arg := range event.Inputs {
			if arg.Indexed {
				continue
			}
			if nonIdx < len(values) {
				fields[arg.Name] = values[nonIdx]
				nonIdx++
			}
		}
	}
	return eventName, fields, nil
}
