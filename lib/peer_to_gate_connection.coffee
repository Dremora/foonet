CommandConnection = require './command_connection'

module.exports = class PeerToGateConnection extends CommandConnection
  @state 'notAuthenticated'
  @state 'authenticating'
  @state 'authenticated'
  @state 'ready'

  authenticate: (id, key) ->
    @send "AUTHENTICATE #{id} #{key}"
    @setState 'authenticating'

  @command /^AUTHENTICATED$/,
    'authenticating',
    ->
      @setState 'authenticated'

  @command /^NOT AUTHENTICATED$/,
    'authenticating',
    ->
      @setState 'notAuthenticated'

  @command /^CONNECTED$/,
    'authenticated',
    ->
      @setState 'ready'
      @socket.removeAllListeners 'data'
      # TODO: change encoding to binary?
      @emit 'ready'
