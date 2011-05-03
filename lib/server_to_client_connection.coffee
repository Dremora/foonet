Address = require './address'
CommandConnection = require './command_connection'

# Hash with authenticated clients
clients = {}

module.exports = class ServerToClientConnection extends CommandConnection
  @state 'notAuthenticated'
  @state 'receivedAddressRequest'
  @state 'authenticated'
  @state 'receivedCapabilities'

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
    (@protocol, port) ->
      @port = parseInt(port) # TODO: check range
      @setState 'receivedCapabilities'

  # Received when peer wants to connect to another peer.
  @command /^CONNECT ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2})$/,
    'receivedCapabilities',
    (address) ->
      if peer = clients[address]
        peer.socket.write "PEER #{@address} IN TCP #{@socket.remoteAddress}\n"
      else
        @socket.write "PEER #{address} MISSING\n"

  # Received when one of the peers is accepting connections from the other
  # one.
  # TODO: make sure CONNECT has been issued before from either peer.
  @command /^WAITING ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2}) ([0-9]{16})$/,
    'receivedCapabilities',
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
