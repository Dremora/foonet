net = require 'net'
events = require('events')
ClientToServerConnection = require './client_to_server_connection'

# Represents a local client. Holds connection to the address master, performs
# and accepts connections to and from remote hosts.
# Fired events:
# `peer', when connection with another peer has beenestablished
# `peerMissing', when requested peer is not available
module.exports = class Client extends events.EventEmitter
  constructor: (port, host, callback) ->
    ports = [
      80
      443
      8080
      Math.floor(Math.random() * 16384) + 49152
    ]

    currentPort = 0
    @port = ports[currentPort]

    @accepting = {}

    @server = net.createServer (socket) =>
      key = ""
      received = (data) =>
        key += data.toString('utf8')
        if key.length < 16
          socket.once 'data', received
        else
          if address = @accepting["#{socket.remoteAddress}_#{key}"]
            socket.on 'close', =>
              delete @accepting["#{socket.remoteAddress}_#{key}"]
            @emit 'peer', address, socket
          else
            socket.end()
      socket.once 'data', received

    @server.on 'error', (error) =>
      switch error.code
        when 'EADDRINUSE', 'EACCES'
          switch error.code
            when 'EADDRINUSE'
              console.log "Port #{@port} is in use"
            when 'EACCES'
              console.log "Access denied for listening on port #{@port}"
          currentPort++
          if currentPort < ports.length
            @port = ports[currentPort]
            @server.listen(@port)
        else throw error

    @server.listen @port, =>
      console.log "Server running at localhost:#{@port}"
      socket = new net.Socket
      socket.connect port, host, =>
        connection = new ClientToServerConnection socket
        connection.client = @
        console.log "Connected to #{host}:#{port}"
        callback(connection)

  # Associate incoming connection from `ip' with `address' and `key'.
  acceptFrom: (address, protocol, ip, key) ->
    switch protocol
      when 'TCP'
        @accepting["#{ip}_#{key}"] = address
      when 'UDP'
        throw new Error 'Not implemented' # TODO

  # Connect to `ip':`port' and associate this host with `address' and `key'.
  connectTo: (address, protocol, ip, port, key) ->
    switch protocol
      when 'TCP'
        socket = new net.Socket
        socket.connect port, ip, =>
          socket.write key
          @emit 'peer', address, socket
      when 'UDP'
        throw new Error 'Not implemented' # TODO
