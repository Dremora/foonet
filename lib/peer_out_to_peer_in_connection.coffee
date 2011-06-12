CommandConnection = require './command_connection'

module.exports = class PeerOutToPeerInConnection extends CommandConnection
  @state 'notAuthenticated'
  @state 'authenticating'
  @state 'ready'

  authenticate: (id, key) ->
    @send "AUTHENTICATE #{id} #{key}"
    @setState 'authenticating'

  @command /^AUTHENTICATED$/,
    'authenticating',
    ->
      @setState 'ready'
      @socket.removeAllListeners 'data'
      # TODO: change encoding to binary?
      @emit 'authenticated'

  @command /^NOT AUTHENTICATED$/,
    'authenticating',
    ->
      @setState 'notAuthenticated'
      @emit 'notAuthenticated'
      @socket.end()
