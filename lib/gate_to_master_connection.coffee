Id = require './id'
CommandConnection = require './command_connection'

module.exports = class GateToMasterConnection extends CommandConnection
  @state 'notAuthenticated'
  @state 'authenticating'
  @state 'ready'

  # Authentication

  @command /^AUTHENTICATED$/,
    'authenticating',
    ->
      @setState 'ready'
      @emit 'authenticated'

  @command /^NOT AUTHENTICATED$/,
    'authenticating',
    ->
      @setState 'notAuthenticated'
      @emit 'notAuthenticated'

  authenticate: (key, port) ->
    @send "AUTHENTICATE #{key} #{port}"
    @setState 'authenticating'

  # Connection

  @command /^CONNECT ([0-9]{16}) ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2}) ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2})$/,
    'ready',
    (key, id1, id2) ->
      @emit 'connectPair', key, new Id(id1), new Id(id2)

  waiting: (key) ->
    @send "WAITING #{key}"
