Id = require './id'
CommandConnection = require './command_connection'

module.exports = class GateToPeerConnection extends CommandConnection
  @state 'notAuthenticated'
  @state 'authenticating'
  @state 'authenticated'
  @state 'ready'

  @command /^AUTHENTICATE ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2}) ([0-9]{16})$/,
    'notAuthenticated',
    (id, key) ->
      @setState 'authenticating'
      @emit 'authenticate', new Id(id), key

  authenticated: ->
    @send 'AUTHENTICATED'
    @setState 'authenticated'

  notAuthenticated: ->
    @send 'NOT AUTHENTICATED'
    @setState 'notAuthenticated'
    @socket.end()

  connected: ->
    @send 'CONNECTED'
    @setState 'ready'
    @socket.removeAllListeners 'data'
    # TODO: change encoding to binary?
