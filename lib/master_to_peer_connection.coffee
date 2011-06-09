net = require 'net'
Id = require './id'
CommandConnection = require './command_connection'

module.exports = class MasterToPeerConnection extends CommandConnection
  @state 'notAuthenticated'
  @state 'receivedIdRequest'
  @state 'authenticated'
  @state 'testingCapabilities'
  @state 'acceptingConnections'

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
        @socket.write "ID #{id}\n"

  # Connectivity capabilities of peer, received right after successful
  # authentication.
  @command /^CAPABILITIES (TCP|UDP) ([0-9]{1,5})$/,
    'authenticated',
    (protocol, port) ->
      port = parseInt(port) # TODO: check range
      @setState 'testingCapabilities'

      # Peer will receive reply when:
      # 1) Connection is successful, or
      # 2) Connection hasn't been established in 5 seconds, or
      # 3) There was an error during connection (e.g. connection refused)
      connection = net.createConnection port, @socket.remoteAddress
      timer = setTimeout ->
        connection.end() # destroy()? drop event handlers?
        @socket.write "CONNECTION ERROR\n"
        @setState 'acceptingConnections'
      , 5000
      connection.on 'connect', =>
        clearTimeout(timer)
        connection.end("ok")
        @port = port
        @socket.write "CONNECTION OK\n"
        @setState 'acceptingConnections'
      connection.on 'error', (error) =>
        clearTimeout(timer)
        @socket.write "CONNECTION ERROR\n"
        @setState 'acceptingConnections'

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

  setId: (@id) ->
    @emit 'setId', id
    @socket.on 'close', =>
      @emit 'close'
    @setState 'authenticated'

  peerMissing: (id) ->
    @socket.write "PEER #{id} MISSING\n"

  authenticated: ->
    @socket.write "AUTHENTICATED\n"

  notAuthenticated: ->
    @socket.write "NOT AUTHENTICATED\n"
    @setState 'notAuthenticated'

  peerIn: (peer) ->
    @socket.write "PEER #{peer.id} IN TCP #{peer.socket.remoteAddress}\n"

  peerOut: (peer, key) ->
    @socket.write "PEER #{peer.id} OUT TCP #{peer.socket.remoteAddress} #{peer.port} #{key}\n"
