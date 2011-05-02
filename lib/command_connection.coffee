module.exports = class CommandConnection
  constructor: (@socket) ->
    @socket.setEncoding 'utf8'
    @buffer = []
    @state = @states.notAuthenticated
    @socket.on 'data', (data) =>
      @received(data)

  received: (data) ->
    @buffer.push x for x in data
    while matches = /^([^\n]+)\n/.exec @buffer.join('')
      command = matches[1]
      @buffer.splice 0, matches[0].length

      for action in @transitions[@state]
        action = @actions[action]
        if matches = action[0].exec command
          matches.splice(0, 1)
          action[1].apply @, matches
          return

      @socket.end("Unknown command - #{command}\n")

  setState: (state) ->
    @state = state
