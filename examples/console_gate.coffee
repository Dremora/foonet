foonet = require '..'
config_loaded = require './config_loader'

config_loaded.load (config) ->
  gate = new foonet.Gate config.master.gatePort, config.gate.host,
  config.master.gateKey, config.gate.peerPort
  gate.on 'error', (error) -> console.log error.message
