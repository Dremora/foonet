Address = require('./address')

module.exports = class ServerConnection
  constructor: (@socket) ->
    @socket.setEncoding 'utf8'
    @buffer = []
    @state = @states.not_authenticated
    @socket.on 'data', (data) =>
      @received(data)

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

  set_state: (state) ->
    @state = state

  received: (data) ->
    @buffer.push x for x in data
    while matches = /^([^\n]+)\n/.exec @buffer.join('')
      command = matches[1]
      @buffer.splice 0, matches[0].length

      for action in @prototype.actions[@transitions[@state]]
        if matches = action[0].exec command
          matches.splice(0, 1)
          action[1].apply @, matches
          return

      @socket.write "Unknown command\n"

  set_address: (address) ->
    @address = new Address address
    @socket.write "ADDRESS #{address}\n"