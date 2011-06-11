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
  constructor: (port, host, @callback) ->
    if net.isIP(host)
      @initialize(port, host)
    else
      dns.lookup host, (error, ip, family) =>
        @initialize(port, ip)

  initialize: (port, ip) ->
    socket = new net.Socket
    socket.connect port, ip, =>
      console.log "Connected to #{ip}:#{port}"
      connection = new PeerToMasterConnection socket
      @callback(connection)

      connection.on 'beginListenTCP', =>
        ports = [
          80
          443
          8080
          Math.floor(Math.random() * 16384) + 49152
        ]
        currentPort = 0
        @port = ports[currentPort]

        # Waits till master connects, then replaces the callback.
        @server = net.createServer (socket) =>
          socket.on 'error', (error) =>
            console.log error.message

          # if socket.remoteAddress == host
            # TODO: set key
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
              else connection.notListeningTCP()
            else throw error

        @server.listen @port, =>
          console.log "Server running at localhost:#{@port}"
          connection.listeningTCP @port

      connection.on 'tcpError', =>
        @server.close()

      connection.on 'tcpOK', =>
        @accepting = {}
        @server.removeAllListeners 'connection'
        @server.on 'connection', (socket) =>
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

      # Associate incoming connection from `ip' with `id' and `key'.
      connection.on 'acceptFrom', (id, protocol, ip, key) =>
        switch protocol
          when 'TCP'
            @accepting["#{ip}_#{key}"] = id
          when 'UDP'
            throw new Error 'Not implemented' # TODO

      # Connect to `ip':`port' and associate this host with `id' and `key'.
      connection.on 'connectTo', (id, protocol, ip, port, key) =>
        switch protocol
          when 'TCP'
            socket = new net.Socket
            socket.connect port, ip, =>
              socket.write key
              @emit 'peer', id, socket
          when 'UDP'
            throw new Error 'Not implemented' # TODO

      connection.on 'peerMissing', (id) =>
        @emit 'peerMissing', id
