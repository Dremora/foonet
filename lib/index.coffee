net = require 'net'
mysql = require './mysql'
ServerToClientConnection = require './server_to_client_connection'
ClientToServerConnection = require './client_to_server_connection'

exports.createServer = (port, mysql_options, callback) ->
  mysql.createConnection mysql_options, (error) ->
    return callback(error) if error
    server = net.createServer (c) ->
      new ServerToClientConnection c

    # Error handling - currently address in use only
    server.on 'error', (error) ->
      if error.code == 'EADDRINUSE'
        callback(error)

    # Begin listening
    server.listen port, ->
      console.log "Server running at localhost:#{port}"
      callback()

exports.createConnection = (port, host, callback) ->
  socket = new net.Socket
  socket.connect port, host, ->
    connection = new ClientToServerConnection socket
    console.log "Connected to #{host}:#{port}"
    callback(connection)
