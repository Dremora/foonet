net = require 'net'
Address = require './address'
CommandConnection = require './command_connection'

# Hash with authenticated clients
clients = {}

module.exports = class ServerToClientConnection extends CommandConnection
  @state 'notAuthenticated'
  @state 'receivedAddressRequest'
  @state 'authenticated'
  @state 'testingCapabilities'
  @state 'acceptingConnections'

  @command /^ADDRESS ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2})$/,
    'notAuthenticated',
    (address) ->
      @setState 'receivedAddressRequest'
      address = new Address(address)
      if clients[address]
        @socket.write "NOT AUTHENTICATED\n"
        @setState 'notAuthenticated'
      else address.find (exists) =>
        if exists
          @setAddress(address)
          @socket.write "AUTHENTICATED\n"
        else
          @socket.write "NOT AUTHENTICATED\n"
          @setState 'notAuthenticated'

  @command /^REQUEST$/,
    'notAuthenticated',
    ->
      @setState 'receivedAddressRequest'
      Address.create (address) =>
        @setAddress(address)
        @socket.write "ADDRESS #{address}\n"

  # Connectivity capabilities of client, received right after successful
  # authentication.
  @command /^CAPABILITIES (TCP|UDP) ([0-9]{1,5})$/,
    'authenticated',
    (protocol, port) ->
      port = parseInt(port) # TODO: check range
      @setState 'testingCapabilities'

      # Client will receive reply when:
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
    (address) ->
      if peer = clients[address]
        # TCP connection is established if at least one of peers supports it
        if peer.port
          peer.socket.write "PEER #{@address} IN TCP #{@socket.remoteAddress}\n"
        else if @port
          @socket.write "PEER #{peer.address} IN TCP #{peer.socket.remoteAddress}\n"
        # If both peers don't support TCP, fallback to UDP hole punching
        else
          throw new Error 'Not implemented' # TODO
      else
        @socket.write "PEER #{address} MISSING\n"

  # Received when one of the peers is accepting connections from the other
  # one.
  # TODO: make sure CONNECT has been issued before from either peer.
  @command /^WAITING ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2}) ([0-9]{16})$/,
    'acceptingConnections',
    (address, key) ->
      if peer = clients[address]
        peer.socket.write "PEER #{@address} OUT TCP #{@socket.remoteAddress} #{@port} #{key}\n"
      else
        @socket.write "PEER #{address} MISSING\n"

  setAddress: (@address) ->
    clients[@address] = @
    console.log "Client #{address} identified"
    @socket.on 'close', =>
      delete clients[@address]
      console.log "Client #{address} quit"
    @setState 'authenticated'
