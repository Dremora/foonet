net = require 'net'
client_connection = require './client_connection'
server_connection = require './server_connection'

exports.createServer = (port) ->
  net.createServer (c) ->
    new client_connection.ClientConnection c
  .listen 8000, ->
    console.log "Server running at localhost:#{port}"

exports.createConnection = (port, host, callback) ->
  socket = new net.Socket
  socket.connect port, host, ->
    connection = new server_connection.ServerConnection socket
    console.log "Connected to #{host}:#{port}"
    callback(connection)
