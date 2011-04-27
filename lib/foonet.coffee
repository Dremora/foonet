net = require 'net'
client_connection = require './client_connection'

exports.createServer = (port) ->
  net.createServer (c) ->
    new client_connection.ClientConnection c
  .listen 8000, ->
    console.log "Server running at localhost:#{port}"
