var PrivateKeyProvider = require("@truffle/hdwallet-provider");

// Insert your private key here
var privateKey = "0x156e5e32e728f2d68639effbb2cd756ac9f87f9c76b44404ac52d9f916a82d8d";
var network_id = 12101          // Change the network ID based on the chain. detailed list is here (https://docs.quai.network/projects/quai-network/sharded-address-space)
var gas = 490335                // Gas limits change, so make sure to update this based on the gas limit for your chain
var protocol = "http"
var host = "127.0.0.1"          // This is the localhost, so please provide your node provider url
var port = 8610                 // This is the http port of zone-1-1 (cyprus1)
var address = "0x1930e0b28d3766e895df661de871a9b8ab70a4da"  // Account to send txs from (account associated with the private key)

module.exports = {
  networks: {
      development: {
        host: "127.0.0.1",      // Localhost (default: none)
        port: 8678,             // Standard Ethereum port (default: none)
        network_id: 9303,       // Any network (default: none)
      },
      quaitestnet: {
        provider: () => new PrivateKeyProvider(privateKey, `${protocol}://${host}:${port}`),
        host: host,
        port: port,              
        network_id: network_id,       
        gas: gas,
        from: address,        
        websocket: true        
      },
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },
};