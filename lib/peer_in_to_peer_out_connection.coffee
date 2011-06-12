CommandConnection = require './command_connection'

module.exports = class PeerInToPeerOutConnection extends CommandConnection
  @state 'notAuthenticated'
  @state 'authenticating'
  @state 'ready'

  @command /^AUTHENTICATE ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2}) ([0-9]{16})$/,
    'notAuthenticated',
    (id, key) ->
      @setState 'authenticating'
      @emit 'authenticate', id, key

  authenticated: ->
    @send 'AUTHENTICATED'
    @setState 'ready'
    @socket.removeAllListeners 'data'
    # TODO: change encoding to binary?

  notAuthenticated: ->
    @send 'NOT AUTHENTICATED'
    @setState 'notAuthenticated'
    @socket.end()
