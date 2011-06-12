Id = require './id'
Key = require './key'
CommandConnection = require './command_connection'

module.exports = class PeerToMasterConnection extends CommandConnection
  @state 'notAuthenticated'
  @state 'idRequested'
  @state 'idSent'
  @state 'tryingToListenTCP'
  @state 'serverIsConnectingTCP'
  @state 'acceptingConnections'

  # Authentication/registration

  @command /^ID ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2})$/,
    'idRequested',
    (id) ->
      @id = new Id id
      console.log "Received id #{id}"
      @setState 'tryingToListenTCP'
      @emit 'beginListenTCP'

  @command /^AUTHENTICATED$/,
    'idSent',
    ->
      console.log 'Authenticated'
      @setState 'tryingToListenTCP'
      @emit 'beginListenTCP'

  @command /^NOT AUTHENTICATED$/,
    'idSent',
    ->
      console.log 'Not authenticated'
      @setState 'notAuthenticated'

  setId: (id) ->
    @id = new Id id
    @send "ID #{id}"
    @setState 'idSent'

  requestId: ->
    @send "REQUEST"
    @setState 'idRequested'

  # Testing incoming TCP connection

  @command /^ERROR$/,
    'serverIsConnectingTCP',
    ->
      console.log 'Error'
      @emit 'tcpError'
      @setState 'acceptingConnections'

  @command /^OK$/,
    'serverIsConnectingTCP',
    ->
      console.log 'OK'
      @emit 'tcpOK'
      @setState 'acceptingConnections'

  listeningTCP: (port) ->
    process.stdout.write 'Tecting incoming TCP connections... '
    @send "LISTENING TCP #{port}"
    @setState 'serverIsConnectingTCP'

  notListeningTCP: ->
    console.log 'Incoming TCP connections not possible'
    @send 'ERROR'
    @setState 'acceptingConnections'

  # Accepting incoming connections

  # Received when a remote host with specified `id' wants to connect
  # to the local host or vice versa, when local host should wait for
  # an incoming connection from the remote host.
  @command /^PEER ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2}) IN (TCP|UDP) ((?:[0-9]{1,3}\.){3}[0-9]{1,3})$/,
    'acceptingConnections',
    (id, protocol, ip) ->
      key = Key.generate()
      @emit 'acceptFrom', new Id(id), protocol, ip, key
      @send "WAITING #{id} #{key}"

  # Received when a remote host with specified `id' wants to connect
  # to the local host or vice versa, when the remote host is ready
  # to accept connections.
  @command /^PEER ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2}) OUT (TCP|UDP) ((?:[0-9]{1,3}\.){3}[0-9]{1,3}) ([0-9]{1,5}) ([0-9]{16})$/,
    'acceptingConnections',
    (id, protocol, ip, port, key) ->
      port = parseInt(port) # TODO: check range
      @emit 'connectTo', new Id(id), protocol, ip, port, key

  # Received when a connection with remote host `id` should be established
  # using gate.
  @command /^PEER ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2}) GATE ((?:[0-9]{1,3}\.){3}[0-9]{1,3}) ([0-9]{1,5}) ([0-9]{16})$/,
    'acceptingConnections',
    (id, ip, port, key) ->
      port = parseInt(port) # TODO: check range
      @emit 'connectTo', new Id(id), 'gate', ip, port, key

  # Received as a responce to a CONNECT or WAITING message when remote host
  # with specified id is not found.
  @command /^PEER ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2}) MISSING$/,
    'acceptingConnections',
    (id) ->
      @emit 'peerMissing', new Id(id)

  connect: (id) ->
    @send "CONNECT #{id}"
