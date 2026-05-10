```shell
forge install OpenZeppelin/openzeppelin-contracts-upgradeable
forge install smartcontractkit/chainlink-brownie-contracts
forge install OpenZeppelin/openzeppelin-contracts
forge install foundry-rs/forge-std
```
在vscode需要安装的插件
```text
Solidity
Nomic Foundation
```

为测试编写nft、erc20、聚合器三个测试合约
然后再setup函数里面初始化，即部署这三个合约，然后在测试函数中使用这几个变量
