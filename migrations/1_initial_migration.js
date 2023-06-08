// const Referral = artifacts.require("Referral");
// const MarketPlace = artifacts.require("MarketPlace");
const MyUSD = artifacts.require("MyUSD");

module.exports = function (deployer) {
  // deployer.deploy(
  //   Referral,
  //   "0x6D635dc4a2A54664B54dF6a63e5ee31D5b29CF6e",
  //   "0x13e1070e3a388e53ec35480ff494538f9ffc5b8d",
  //   "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d",
  //   "0x85f94745D1B401617119a4E53F11484053C0EA42",
  //   "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c",
  //   "0x10ED43C718714eb63d5aA57B78B54704E256024E"
  // );
  // deployer.deploy(
  //   MarketPlace,
  //   "0x6D635dc4a2A54664B54dF6a63e5ee31D5b29CF6e",
  //   "0xAD9317601872De47a92A175a94Feb18e72CB5bD5",
  //   "0x1A2c2204fEe5355080a1bCbC0F4E8aDd58d4b6d7",
  // );
  deployer.deploy(MyUSD);
};
