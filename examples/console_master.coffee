foonet = require '..'
config_loaded = require './config_loader'

config_loaded.load (config) ->
  master = new foonet.Master config.master.peerPort, config.master.gatePort,
  config.master.mysql, config.master.gateKey
  master.on 'error', (error) -> console.log error.message
