Address = require './address'
CommandConnection = require './command_connection'

# Hash with authenticated clients
clients = {}

module.exports = class ServerToClientConnection extends CommandConnection
  states:
    notAuthenticated: 'notAuthenticated'
    receivedAddressRequest: 'receivedAddressRequest'
    authenticated: 'authenticated'
    receivedCapabilities: 'receivedCapabilities'

  actions:
    parseAddress: [
      /^ADDRESS ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2})$/
      (address) ->
        @setState @states.receivedAddressRequest
        address = new Address(address)
        if clients[address]
          @socket.write "NOT AUTHENTICATED\n"
          @setState @states.notAuthenticated
        else address.find (exists) =>
          if exists
            @setAddress(address)
            @socket.write "AUTHENTICATED\n"
          else
            @socket.write "NOT AUTHENTICATED\n"
            @setState @states.notAuthenticated
    ]

    requestAddress: [
      /^REQUEST$/
      ->
        @setState @states.receivedAddressRequest
        Address.create (address) =>
          @setAddress(address)
          @socket.write "ADDRESS #{address}\n"
    ]

    # Connectivity capabilities of client, received right after successful
    # authentication.
    capabilities: [
      /^CAPABILITIES (TCP|UDP) ([0-9]{1,5})$/
      (@protocol, port) ->
        @port = parseInt(port) # TODO: check range
        @setState @states.receivedCapabilities
    ]

    # Received when peer wants to connect to another peer.
    connect: [
      /^CONNECT ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2})$/
      (address) ->
        if peer = clients[address]
          peer.socket.write "PEER #{@address} IN TCP #{@socket.remoteAddress}\n"
        else
          @socket.write "PEER #{address} MISSING\n"
    ]

    # Received when one of the peers is accepting connections from the other
    # one.
    # TODO: make sure CONNECT has been issued before from either peer.
    waiting: [
      /^WAITING ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2}) ([0-9]{16})$/
      (address, key) ->
        if peer = clients[address]
          peer.socket.write "PEER #{@address} OUT TCP #{@socket.remoteAddress} #{@port} #{key}\n"
        else
          @socket.write "PEER #{address} MISSING\n"
    ]

  transitions:
    notAuthenticated: [
      'requestAddress'
      'parseAddress'
    ]
    receivedAddressRequest: []
    authenticated: [
      'capabilities'
    ]
    receivedCapabilities: [
      'connect'
      'waiting'
    ]

  setAddress: (@address) ->
    clients[@address] = @
    console.log "Client #{address} identified"
    @socket.on 'close', =>
      delete clients[@address]
      console.log "Client #{address} quit"
    @setState @states.authenticated
