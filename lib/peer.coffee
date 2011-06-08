dns = require 'dns'
net = require 'net'
events = require 'events'
PeerToMasterConnection = require './peer_to_master_connection'

# Represents a local peer. Holds connection to the master, performs
# and accepts connections to and from remote hosts.
# Fired events:
# `peer', when connection with another peer has beenestablished
# `peerMissing', when requested peer is not available
module.exports = class Peer extends events.EventEmitter
  constructor: (port, host, callback) ->
    if net.isIP(host)
      @initialize port, host, callback
    else
      dns.lookup host, (error, id, family) =>
        @initialize port, id, callback

  initialize: (port, host, callback) ->
    ports = [
      80
      443
      8080
      Math.floor(Math.random() * 16384) + 49152
    ]

    currentPort = 0
    @port = ports[currentPort]

    @accepting = {}

    # Will replace default callback after successful connection from master.
    peerCallback = (socket) =>
      key = ""
      received = (data) =>
        key += data.toString('utf8')
        if key.length < 16
          socket.once 'data', received
        else
          if id = @accepting["#{socket.remoteAddress}_#{key}"]
            socket.on 'close', =>
              delete @accepting["#{socket.remoteAddress}_#{key}"]
            @emit 'peer', id, socket
          else
            socket.end()
      socket.once 'data', received

    # Waits till master connects, then replaces the callback.
    @server = net.createServer (socket) =>
      socket.on 'error', (error) =>
        console.log error.message

      if socket.remoteAddress == host
        @server.removeAllListeners 'connection'
        @server.on 'connection', peerCallback
      socket.end()

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
        connection = new PeerToMasterConnection socket
        connection.peer = @
        console.log "Connected to #{host}:#{port}"
        callback(connection)

  # Associate incoming connection from `ip' with `id' and `key'.
  acceptFrom: (id, protocol, ip, key) ->
    switch protocol
      when 'TCP'
        @accepting["#{ip}_#{key}"] = id
      when 'UDP'
        throw new Error 'Not implemented' # TODO

  # Connect to `ip':`port' and associate this host with `id' and `key'.
  connectTo: (id, protocol, ip, port, key) ->
    switch protocol
      when 'TCP'
        socket = new net.Socket
        socket.connect port, ip, =>
          socket.write key
          @emit 'peer', id, socket
      when 'UDP'
        throw new Error 'Not implemented' # TODO
