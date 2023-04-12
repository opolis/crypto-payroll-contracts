const config = require("./config.json");

module.exports = [
  config.opolisAdmin,
  config.opolisHelper,
  config.ethLiq,
  [config.usdcAddress, config.daiAddress, config.usdtAddress],
  [config.usdcLiq, config.daiLiq, config.usdtLiq],
];
