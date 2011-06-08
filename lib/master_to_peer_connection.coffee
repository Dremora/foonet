net = require 'net'
Id = require './id'
CommandConnection = require './command_connection'

# Hash with authenticated peers
peers = {}

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
      id = new Id(id)
      if peers[id]
        @socket.write "NOT AUTHENTICATED\n"
        @setState 'notAuthenticated'
      else id.find (exists) =>
        if exists
          @setId(id)
          @socket.write "AUTHENTICATED\n"
        else
          @socket.write "NOT AUTHENTICATED\n"
          @setState 'notAuthenticated'

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
      if peer = peers[id]
        # TCP connection is established if at least one of peers supports it
        if peer.port
          peer.socket.write "PEER #{@id} IN TCP #{@socket.remoteAddress}\n"
        else if @port
          @socket.write "PEER #{peer.id} IN TCP #{peer.socket.remoteAddress}\n"
        # If both peers don't support TCP, fallback to UDP hole punching
        else
          throw new Error 'Not implemented' # TODO
      else
        @socket.write "PEER #{id} MISSING\n"

  # Received when one of the peers is accepting connections from the other
  # one.
  # TODO: make sure CONNECT has been issued before from either peer.
  @command /^WAITING ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2}) ([0-9]{16})$/,
    'acceptingConnections',
    (id, key) ->
      if peer = peers[id]
        peer.socket.write "PEER #{@id} OUT TCP #{@socket.remoteAddress} #{@port} #{key}\n"
      else
        @socket.write "PEER #{id} MISSING\n"

  setId: (@id) ->
    peers[@id] = @
    console.log "Peer #{id} identified"
    @socket.on 'close', =>
      delete peers[@id]
      console.log "Peer #{id} quit"
    @setState 'authenticated'
