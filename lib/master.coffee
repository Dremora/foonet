events = require 'events'
mysql = require './mysql'
net = require 'net'
Key = require './key'
MasterToPeerConnection = require './master_to_peer_connection'
MasterToGateConnection = require './master_to_gate_connection'

module.exports = class Master extends events.EventEmitter
  constructor: (@peerPort, @gatePort, mysqlOptions, @key) ->

    # Hash with authenticated peers
    @peers = {}

    # Authenticated gates
    @gates = []

    # Peers waiting for connection using gate
    @gateConnections = {}

    @createMySQLServer(mysqlOptions)

  createMySQLServer: (options) ->
    mysql.createConnection options, (error) =>
      @emit 'error', error if error
      @createGateServer()

  createGateServer: ->
    gateServer = net.createServer (socket) => @gateConnection(socket)
    gateServer.on 'error', (error) => @emit 'error', error
    gateServer.listen @gatePort, =>
      console.log "Waiting for gates on localhost:#{@gatePort}"
      @createPeerServer()

  createPeerServer: ->
    server = net.createServer (socket) => @peerConnection(socket)
    server.on 'error', (error) => @emit 'error', error
    server.listen @peerPort, =>
      console.log "Waiting for peers at localhost:#{@peerPort}"
      @emit 'ready'

  # Called when a new gate makes connection to the master
  gateConnection: (socket) ->
    gate = new MasterToGateConnection(socket)

    # Called when gate tries to authenticate
    gate.on 'authenticate', (key) =>
      if key == @key
        console.log "Gate #{socket.remoteAddress}:#{socket.remotePort} connected"
        gate.authenticated()
        @gates.push gate
        gate.socket.on 'close', =>
          console.log "Gate #{socket.remoteAddress}:#{socket.remotePort} disconnected"
          i = 0
          while i < @gates.length
            if @gates[i] == gate
              @gates.splice(i, 1)
              return
            i += 1
      else gate.notAuthenticated()

    # Called when gate is ready to connect two peers
    gate.on 'waiting', (key) =>
      [peerId, otherId] = @gateConnections[key]
      peer = @peers[peerId]
      other = @peers[otherId]
      delete @gateConnections[key]
      if !peer && other
        other.peerMissing peerId
      else if peer && !other
        peer.peerMissing otherId
      else if peer && other
        peer.peerGate other, gate.socket.remoteAddress, gate.port, key
        other.peerGate peer, gate.socket.remoteAddress, gate.port, key

  # Fired when a new peer is connected
  peerConnection: (socket) ->
    peer = new MasterToPeerConnection socket

    peer.on 'id', (id) =>
      if @peers[id]
        peer.notAuthenticated()
      else id.find (exists) =>
        if exists
          peer.setId(id)
          peer.authenticated()
        else
          peer.notAuthenticated()

    peer.on 'setId', (id) =>
      @peers[id] = peer
      console.log "Peer #{id} identified"
      peer.on 'close', =>
        delete @peers[id]
        console.log "Peer #{id} quit"

    peer.on 'waiting', (id, key) =>
      if other = @peers[id]
        other.peerOut peer, key
      else
        peer.peerMissing id

    peer.on 'connect', (id) =>
      if (other = @peers[id])?.isState('acceptingConnections')
        # TCP connection is established if at least one of peers supports it
        if other.supports 'incomingTCP'
          other.peerIn peer
        else if peer.supports 'incomingTCP'
          peer.peerIn other
        # If both peers don't support incoming TCP, fallback to gate
        else
          # TODO: check length, select least loaded gate
          key = Key.generate()
          @gateConnections[key] = [peer.id, other.id]
          @gates[0].connect key, peer.id, other.id
      else
        peer.peerMissing id
