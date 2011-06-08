net = require 'net'
mysql = require './mysql'
MasterToPeerConnection = require './master_to_peer_connection'

exports.createMaster = (port, mysqlOptions, callback) ->
  mysql.createConnection mysqlOptions, (error) ->
    return callback(error) if error
    server = net.createServer (c) ->
      new MasterToPeerConnection c

    # Error handling - currently id in use only
    server.on 'error', (error) ->
      if error.code == 'EADDRINUSE'
        callback(error)
      else throw error

    # Begin listening
    server.listen port, ->
      console.log "Master running at localhost:#{port}"
      callback()

exports.Peer = require './peer'
