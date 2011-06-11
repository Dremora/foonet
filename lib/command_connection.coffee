events = require 'events'

module.exports = class CommandConnection extends events.EventEmitter
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

  # Adds a new state to the class. Should not be used after `@command'.
  @state: (state) ->
    @::states ?= {}
    @states_count ?= 0
    @::states[state] = @states_count

    @::transitions ?= []
    @::transitions[@states_count] = []

    @states_count = @states_count + 1

  # Defines a new `action' as a response to the `command' regex for the
  # specified `states' (can be either a single state or an array).
  @command: (command, states, action) ->
    @::actions ?= []
    @actions_count ?= 0
    @::actions.push [command, action]

    for state in (if states instanceof Array then states else [states])
      @::transitions[@::states[state]].push @actions_count

    @actions_count = @actions_count + 1

  setState: (state) ->
    @state = @states[state]

  send: (command) ->
    @socket.write "#{command}\n"
