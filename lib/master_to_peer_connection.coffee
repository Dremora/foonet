net = require 'net'
Id = require './id'
CommandConnection = require './command_connection'

module.exports = class MasterToPeerConnection extends CommandConnection

  supports: (name) ->
    @capabilities ?= {}
    @capabilities.hasOwnProperty(name)

  capability: (name) ->
    @capabilities ?= {}
    @capabilities[name] = true

  @state 'notAuthenticated'
  @state 'receivedIdRequest'
  @state 'waitingCapabilitiesTCP'
  @state 'testingCapabilitiesTCP'
  @state 'acceptingConnections'

  # Authentication/registration

  @command /^ID ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2})$/,
    'notAuthenticated',
    (id) ->
      @setState 'receivedIdRequest'
      @emit 'id', new Id(id)

  @command /^REQUEST$/,
    'notAuthenticated',
    ->
      @setState 'receivedIdRequest'
      Id.create (id) =>
        @setId(id)
        @send "ID #{id}"

  setId: (@id) ->
    @emit 'setId', id
    @socket.on 'close', =>
      @emit 'close'

  authenticated: ->
    @send "AUTHENTICATED"
    @setState 'waitingCapabilitiesTCP'

  notAuthenticated: ->
    @send "NOT AUTHENTICATED"
    @setState 'notAuthenticated'

  # Testing incoming TCP connection

  # Connectivity capabilities of peer, received right after successful
  # authentication.
  @command /^LISTENING TCP ([0-9]{1,5})$/,
    'waitingCapabilitiesTCP',
    (port) ->
      port = parseInt(port) # TODO: check range
      @setState 'testingCapabilitiesTCP'

      # Peer will receive reply when:
      # 1) Connection is successful, or
      # 2) Connection hasn't been established in 5 seconds, or
      # 3) There was an error during connection (e.g. connection refused)
      connection = net.createConnection port, @socket.remoteAddress
      timer = setTimeout ->
        connection.end() # destroy()? drop event handlers?
        @notConnectedTCP()
      , 5000
      connection.on 'connect', =>
        clearTimeout(timer)
        connection.end("ok")
        @port = port
        @connectedTCP()
      connection.on 'error', (error) =>
        clearTimeout(timer)
        @notConnectedTCP()

  # Peer was unable to begin listening
  @command /^ERROR$/,
    'waitingCapabilitiesTCP',
    ->
      @setState 'acceptingConnections'

  connectedTCP: ->
    @capability 'incomingTCP'
    @send 'OK'
    @setState 'acceptingConnections'

  notConnectedTCP: ->
    @send 'ERROR'
    @setState 'acceptingConnections'

  # Accepting incoming connections

  # Received when peer wants to connect to another peer.
  @command /^CONNECT ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2})$/,
    'acceptingConnections',
    (id) ->
      @emit 'connect', id

  # Received when one of the peers is accepting connections from the other
  # one.
  # TODO: make sure CONNECT has been issued before from either peer.
  @command /^WAITING ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2}) ([0-9]{16})$/,
    'acceptingConnections',
    (id, key) ->
      @emit 'waiting' , id, key

  peerMissing: (id) ->
    @send "PEER #{id} MISSING"

  peerIn: (peer) ->
    @send "PEER #{peer.id} IN TCP #{peer.socket.remoteAddress}"

  peerOut: (peer, key) ->
    @send "PEER #{peer.id} OUT TCP #{peer.socket.remoteAddress} #{peer.port} #{key}"
