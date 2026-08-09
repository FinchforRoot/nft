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
== Logs ==
ETH/USD Aggregator deployed at: 0xbA62C5de7aa2eFd6b2FEAa72562D95678Ce97D93
USDT/USD Aggregator deployed at: 0xed93426dA94D27dCfd3e3949D051882Ccae31614
USDT deployed at: 0xfFdb5E3F6832350847Af88088f682746c441a830
TestMyNft deployed at: 0x626dBa4aE86F0ca323A89A5FBaac53db59a79737
NftAuction Implementation deployed at: 0x241999f052ab292Aaf1f89b1C2AD5EDc80110609
ERC1967Proxy deployed at: 0xF3E4794B7a5a766d7675955c127831eA28Fa80C8
ETH/USD Price Feed registered: 0xbA62C5de7aa2eFd6b2FEAa72562D95678Ce97D93
USDT/USD Price Feed registered: 0xed93426dA94D27dCfd3e3949D051882Ccae31614
Minted 1000 USDT to deployer: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
Minted NFT tokenId 0 to deployer: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
===================================
Deployment Summary:
ETH/USD Aggregator: 0xbA62C5de7aa2eFd6b2FEAa72562D95678Ce97D93
USDT/USD Aggregator: 0xed93426dA94D27dCfd3e3949D051882Ccae31614
USDT Token: 0xfFdb5E3F6832350847Af88088f682746c441a830
TestMyNft: 0x626dBa4aE86F0ca323A89A5FBaac53db59a79737
NftAuction Implementation: 0x241999f052ab292Aaf1f89b1C2AD5EDc80110609
NftAuction Proxy: 0xF3E4794B7a5a766d7675955c127831eA28Fa80C8
Deployer: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
===================================

部署命令
```text
forge build
forge script script/NftAuction.s.sol --rpc-url $SEPOLIA_RPC_URL --account deployer1 --broadcast
这里的deployer1是自己本地账户起的别名，用cast wallet import deployer1 --interactive命令创建的，相当于--private-key $PRIVATE_KEY
```