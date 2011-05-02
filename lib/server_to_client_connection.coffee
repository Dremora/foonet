Address = require './address'
CommandConnection = require './command_connection'

# Hash with authenticated clients
clients = {}

module.exports = class ServerToClientConnection extends CommandConnection
  states:
    not_authenticated: 'not_authenticated'
    received_address_request: 'received_address_request'
    authenticated: 'authenticated'
    received_capabilities: 'received_capabilities'

  actions:
    parse_address: [
      /^ADDRESS ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2})$/
      (address) ->
        @set_state @states.received_address_request
        address = new Address(address)
        if clients[address]
          @socket.write "NOT AUTHENTICATED\n"
          @set_state @states.not_authenticated
        else address.find (exists) =>
          if exists
            @set_address(address)
            @socket.write "AUTHENTICATED\n"
          else
            @socket.write "NOT AUTHENTICATED\n"
            @set_state @states.not_authenticated
    ]

    request_address: [
      /^REQUEST$/
      ->
        @set_state @states.received_address_request
        Address.create (address) =>
          @set_address(address)
          @socket.write "ADDRESS #{address}\n"
    ]

    # Connectivity capabilities of client, received right after successful
    # authentication.
    capabilities: [
      /^CAPABILITIES (TCP|UDP) ([0-9]{1,5})$/
      (@protocol, port) ->
        @port = parseInt(port) # TODO: check range
        @set_state @states.received_capabilities
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
    not_authenticated: [
      'request_address'
      'parse_address'
    ]
    received_address_request: []
    authenticated: [
      'capabilities'
    ]
    received_capabilities: [
      'connect'
      'waiting'
    ]

  set_address: (@address) ->
    clients[@address] = @
    console.log "Client #{address} identified"
    @socket.on 'close', =>
      delete clients[@address]
      console.log "Client #{address} quit"
    @set_state @states.authenticated
