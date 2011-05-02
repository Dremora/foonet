net = require 'net'
mysql = require './mysql'
ServerToClientConnection = require './server_to_client_connection'

exports.createServer = (port, mysqlOptions, callback) ->
  mysql.createConnection mysqlOptions, (error) ->
    return callback(error) if error
    server = net.createServer (c) ->
      new ServerToClientConnection c

    # Error handling - currently address in use only
    server.on 'error', (error) ->
      if error.code == 'EADDRINUSE'
        callback(error)
      else throw error

    # Begin listening
    server.listen port, ->
      console.log "Server running at localhost:#{port}"
      callback()

exports.Client = require './client'
