net = require 'net'
events = require('events')
ClientToServerConnection = require './client_to_server_connection'

# Represents a local client. Holds connection to the address master, performs
# and accepts connections to and from remote hosts.
module.exports = class Client extends events.EventEmitter
  constructor: (port, host, callback) ->
    ports = [
      80
      443
      8080
      Math.floor(Math.random() * 16384) + 49152
    ]

    current_port = 0
    @port = ports[current_port]

    @server = net.createServer (connection) ->
      # TODO

    @server.on 'error', (error) =>
      switch error.code
        when 'EADDRINUSE', 'EACCES'
          switch error.code
            when 'EADDRINUSE'
              console.log "Port #{@port} is in use"
            when 'EACCES'
              console.log "Access denied for listening on port #{@port}"
          current_port++
          if current_port < ports.length
            @port = ports[current_port]
            @server.listen(@port)
        else throw error

    @server.listen @port, =>
      console.log "Server running at localhost:#{@port}"
      socket = new net.Socket
      socket.connect port, host, ->
        connection = new ClientToServerConnection socket
        console.log "Connected to #{host}:#{port}"
        callback(connection)
