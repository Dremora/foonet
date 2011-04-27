# Hash with authenticated clients
clients = {}

module.exports = class ClientConnection
  constructor: (@socket) ->
    @socket.setEncoding 'utf8'
    @buffer = []
    @state = @states.not_authenticated
    @socket.on 'data', (data) =>
      @received(data)

  states:
    not_authenticated: 'not_authenticated'
    authenticated: 'authenticated'

  actions:
    parse_address: [
      /^ADDRESS ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2})$/
      (address) ->
        @address = address
        clients[address] = @
        console.log "Client #{address} identified"
        @set_state @states.authenticated
        @socket.on 'close', ->
          delete clients[@address]
          console.log "Client #{address} quit"
    ]

    request_address: [
      /^REQUEST$/
      ->
        # TODO
    ]

    connect: [
      /^CONNECT (.{4})$/
      (address) ->
        # TODO
    ]

  transitions:
    not_authenticated: [
      `ClientConnection.prototype.actions.request_address`
      `ClientConnection.prototype.actions.parse_address`
    ]
    authenticated: [
      `ClientConnection.prototype.actions.connect`
    ]

  set_state: (state) ->
    @state = state

  received: (data) ->
    @buffer.push x for x in data
    while matches = /^([^\n]+)\n/.exec @buffer.join('')
      command = matches[1]
      @buffer.splice 0, matches[0].length

      for action in @transitions[@state]
        if matches = action[0].exec command
          matches.splice(0, 1)
          action[1].apply @, matches
          return

      @socket.write "Unknown command\n"
