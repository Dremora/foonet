CommandConnection = require './command_connection'

module.exports = class MasterToGateConnection extends CommandConnection
  @state 'notAuthenticated'
  @state 'authenticating'
  @state 'ready'

  # Authentication

  @command /^AUTHENTICATE ([0-9]{16}) ([0-9]{1,5})$/,
    'notAuthenticated',
    (key, port) ->
      @port = parseInt(port) # TODO: check range
      @setState 'authenticating'
      @emit 'authenticate', key

  authenticated: ->
    @send 'AUTHENTICATED'
    @setState 'ready'

  notAuthenticated: ->
    @send 'NOT AUTHENTICATED'
    @setState 'notAuthenticated'

  # Connection

  @command /^WAITING ([0-9]{16})$/,
    'ready',
    (key) ->
      @emit 'waiting', key

  connect: (key, id1, id2) ->
    @send "CONNECT #{key} #{id1} #{id2}"
