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


最新部署地址
```text
  Deployment Summary:
  ETH/USD Aggregator: 0x47b61E8BD84A71636f946395eC0c06Cb469e0047
  USDT/USD Aggregator: 0x4aC70c2877b433b7E9F05ea8B1d51866536cA481
  USDT Token: 0x5E2e299edCd1b083b858bFbC49944C277ebf1D00
  TestMyNft: 0x5541f9f7E689f6EE712Fc46A934b90A36E79A2fD
  NftAuction Implementation: 0x261DCc31A34524c28F0D9078dD375f1024678959
  NftAuction Proxy: 0xa1EaE6652e6CBCbc70048196B105904ED385F058
  Deployer: 0x2b03639904180eFaf22DdC811F4B878b85e1406E

```

部署命令
```text
forge build
forge script script/NftAuction.s.sol --rpc-url $SEPOLIA_RPC_URL --account deployer1 --sender 账户地址 --broadcast
这里的deployer1是自己本地账户起的别名，用cast wallet import deployer1 --interactive命令创建的，相当于--private-key $PRIVATE_KEY
这里有个大坑：
forge script script/NftAuction.s.sol --rpc-url $SEPOLIA_RPC_URL --account deployer1 --broadcast
不加--sender 的话  无法解析--account到msg.sender
```