Id = require './id'
CommandConnection = require './command_connection'

module.exports = class PeerToMasterConnection extends CommandConnection
  @state 'notAuthenticated'
  @state 'idRequested'
  @state 'idSent'
  @state 'capabilitiesSent'
  @state 'authenticated'

  @command /^ID ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2})$/,
    'idRequested',
    (id) ->
      @id = new Id id
      console.log "Received id #{id}"
      @socket.write "CAPABILITIES TCP #{@peer.port}\n"
      @setState 'capabilitiesSent'

  @command /^AUTHENTICATED$/,
    'idSent',
    ->
      console.log 'Authenticated'
      @socket.write "CAPABILITIES TCP #{@peer.port}\n"
      @setState 'capabilitiesSent'

  @command /^NOT AUTHENTICATED$/,
    'idSent',
    ->
      console.log 'Not authenticated'
      @setState 'notAuthenticated'

  @command /^CONNECTION ERROR$/,
    'capabilitiesSent',
    ->
      console.log 'TCP connection not possible'
      @peer.server.removeAllListeners('connection')
      @peer.server.close()
      @setState 'authenticated'

  @command /^CONNECTION OK$/,
    'capabilitiesSent',
    ->
      console.log 'TCP OK'
      @setState 'authenticated'

  # Received when a remote host with specified `id' wants to connect
  # to the local host or vice versa, when local host should wait for
  # an incoming connection from the remote host.
  @command /^PEER ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2}) IN (TCP|UDP) ((?:[0-9]{1,3}\.){3}[0-9]{1,3})$/,
    'authenticated',
    (id, protocol, ip) ->
      key = Math.floor(Math.random() * 10000000000000000).toString()
      while key.length < 16
        key = '0' + key
      @peer.acceptFrom id, protocol, ip, key
      @socket.write "WAITING #{id} #{key}\n"

  # Received when a remote host with specified `id' wants to connect
  # to the local host or vice versa, when the remote host is ready
  # to accept connections.
  @command /^PEER ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2}) OUT (TCP|UDP) ((?:[0-9]{1,3}\.){3}[0-9]{1,3}) ([0-9]{1,5}) ([0-9]{16})$/,
    'authenticated',
    (id, protocol, ip, port, key) ->
      port = parseInt(port) # TODO: check range
      @peer.connectTo id, protocol, ip, port, key

  # Received as a responce to a CONNECT or WAITING message when remote host
  # with specified id is not found.
  @command /^PEER ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2}) MISSING$/,
    'authenticated',
    (id) ->
      @peer.emit 'peerMissing', new Id(id)

  setId: (id) ->
    @id = new Id id
    @socket.write "ID #{id}\n"
    @setState 'idSent'

  requestId: ->
    @socket.write "REQUEST\n"
    @setState 'idRequested'

  connect: (id) ->
    @socket.write "CONNECT #{id}\n"
