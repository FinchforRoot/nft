1.正常开发过程  lib目录的代码需要提交到git仓库吗

2.进行测试查看报错信息的详细信息时  使用forge test -vvvvv吗？在进行调试的时候  是在主合约方法内部console.log吗 需要导入哪个包？

3.进行测试的时候  是不是在test方法内部的block.timestamp和合约内部函数中使用到的block.timestamp是同一时间

4.在进行事件测试的时候  是不是需要先
vm.expectEmit(true, true, true, true);
然后再
// 验证事件被触发
emit AuctionCreated(0, seller, address(nft), TOKEN_ID, START_PRICE, block.timestamp, DURATION_HOURS);
最后再调用合约的方法进行事件验证？

