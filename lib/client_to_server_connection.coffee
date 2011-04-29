Address = require('./address')
CommandConnection = require './command_connection'

module.exports = class ClientToServerConnection extends CommandConnection
  states:
    not_authenticated: 'not_authenticated'
    address_requested: 'address_requested'
    address_sent: 'address_sent'
    authenticated: 'authenticated'

  actions:
    parse_address: [
      /^ADDRESS ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2})$/
      (address) ->
        @address = new Address address
        console.log "Received address #{address}"
        @set_state @states.authenticated
    ]

    authenticated: [
      /^AUTHENTICATED$/
      ->
        console.log 'Authenticated'
        @set_state @states.authenticated
    ]

    not_authenticated: [
      /^NOT AUTHENTICATED$/
      ->
        console.log 'Not authenticated'
        @set_state @states.not_authenticated
    ]

  transitions:
    not_authenticated: []
    address_requested: [
      'parse_address'
    ]
    address_sent: [
      'authenticated'
      'not_authenticated'
    ]
    authenticated: []

  set_address: (address) ->
    @address = new Address address
    @socket.write "ADDRESS #{address}\n"
    @set_state @states.address_sent

  request_address: ->
    @socket.write "REQUEST\n"
    @set_state @states.address_requested
