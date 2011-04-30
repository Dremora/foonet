Address = require './address'
CommandConnection = require './command_connection'

# Hash with authenticated clients
clients = {}

module.exports = class ServerToClientConnection extends CommandConnection
  states:
    not_authenticated: 'not_authenticated'
    received_address_request: 'received_address_request'
    authenticated: 'authenticated'

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

    connect: [
      /^CONNECT (.{4})$/
      (address) ->
        # TODO
    ]

  transitions:
    not_authenticated: [
      'request_address'
      'parse_address'
    ]
    authenticated: [
      'connect'
    ]
    received_address_request: []

  set_address: (address) ->
    @address = address
    clients[@address] = @
    console.log "Client #{address} identified"
    @socket.on 'close', ->
      delete clients[@address]
      console.log "Client #{address} quit"
    @set_state @states.authenticated
