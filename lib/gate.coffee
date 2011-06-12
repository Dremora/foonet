events = require 'events'
net = require 'net'
Id = require './id'
GateToMasterConnection = require './gate_to_master_connection'
GateToPeerConnection = require './gate_to_peer_connection'

module.exports = class Gate extends events.EventEmitter
  constructor: (@masterAddress, @masterPort, @key, @listenPort) ->
    @peers = {}
    @connections = {}
    @createServer(listenPort)

  createServer: (port) ->
    @server = net.createServer (socket) => socket.end()
    @server.on 'error', (error) => @emit 'error', error
    @server.listen port, =>
      console.log "Gate running at localhost:#{port}"
      socket = net.createConnection @masterAddress, @masterPort
      socket.on 'error', (error) => @emit 'error', error
      socket.on 'connect', => @masterConnection(socket)

  # Called when connection with master has been established.
  masterConnection: (socket) ->
    @master = new GateToMasterConnection(socket)
    @master.authenticate(@key, @listenPort)

    @master.on 'authenticated', =>
      console.log 'Authenticated'
      @server.removeAllListeners 'connection'
      @server.on 'connection', (socket) => @peerConnection(socket)
      @emit 'ready'

    @master.on 'notAuthenticated', =>
      console.log 'Authentication error'
      socket.end()

    @master.on 'connectPair', (key, id1, id2) =>
      @peers[key] = [id1, id2]
      @master.waiting(key)

  # Called when a peer makes connection to the gate
  peerConnection: (socket) ->
    peer = new GateToPeerConnection(socket)
    peer.on 'authenticate', (id, key) =>
      ids = @peers[key]

      # First peer
      if ids instanceof Array
        if Id.equals(ids[0], id)
          @peers[key] = ids[1]
          @connections[key] = peer
          peer.authenticated()
        else if Id.equals(ids[1], id)
          @peers[key] = ids[0]
          @connections[key] = peer
          peer.authenticated()
        else peer.notAuthenticated()

      # Second peer
      else if Id.equals(ids, id)
        peer2 = @connections[key]
        delete @connections[key]
        delete @peers[key]
        peer.authenticated()
        peer.connected()
        peer2.connected()
        # Piping sockets
        peer.socket.pipe peer2.socket
        peer2.socket.pipe peer.socket

      else peer.notAuthenticated()
