net = require 'net'
mysql = require './mysql'
client_connection = require './client_connection'
server_connection = require './server_connection'

exports.createServer = (port, mysql_options, callback) ->
  mysql.createConnection mysql_options, (error) ->
    return callback(error) if error
    server = net.createServer (c) ->
      new client_connection.ClientConnection c

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
    connection = new server_connection.ServerConnection socket
    console.log "Connected to #{host}:#{port}"
    callback(connection)
