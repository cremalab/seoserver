(function() {
  var config;

  config = {
    host: "" + process.env.HOST_URL + "",
    defaultPort: process.env.PORT ,
    memjs: {
      enabled: false,
      key: 'public'
    },
    logentries: {
      enabled: false,
      token: 'YOUR_LOGENTRIES_TOKEN_HERE'
    }
    // getParamWhitelist: ['page']
  };

  module.exports = config;

}).call(this);
