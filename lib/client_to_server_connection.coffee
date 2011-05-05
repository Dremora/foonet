Address = require './address'
CommandConnection = require './command_connection'

module.exports = class ClientToServerConnection extends CommandConnection
  @state 'notAuthenticated'
  @state 'addressRequested'
  @state 'addressSent'
  @state 'capabilitiesSent'
  @state 'authenticated'

  @command /^ADDRESS ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2})$/,
    'addressRequested',
    (address) ->
      @address = new Address address
      console.log "Received address #{address}"
      @socket.write "CAPABILITIES TCP #{@client.port}\n"
      @setState 'capabilitiesSent'

  @command /^AUTHENTICATED$/,
    'addressSent',
    ->
      console.log 'Authenticated'
      @socket.write "CAPABILITIES TCP #{@client.port}\n"
      @setState 'capabilitiesSent'

  @command /^NOT AUTHENTICATED$/,
    'addressSent',
    ->
      console.log 'Not authenticated'
      @setState 'notAuthenticated'

  @command /^CONNECTION ERROR$/,
    'capabilitiesSent',
    ->
      console.log 'TCP connection not possible'
      @client.server.removeAllListeners('connection')
      @client.server.close()
      @setState 'authenticated'

  @command /^CONNECTION OK$/,
    'capabilitiesSent',
    ->
      console.log 'TCP OK'
      @setState 'authenticated'

  # Received when a remote host with specified `address' wants to connect
  # to the local host or vice versa, when local host should wait for
  # an incoming connection from the remote host.
  @command /^PEER ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2}) IN (TCP|UDP) ((?:[0-9]{1,3}\.){3}[0-9]{1,3})$/,
    'authenticated',
    (address, protocol, ip) ->
      key = Math.floor(Math.random() * 10000000000000000).toString()
      while key.length < 16
        key = '0' + key
      @client.acceptFrom address, protocol, ip, key
      @socket.write "WAITING #{address} #{key}\n"

  # Received when a remote host with specified `address' wants to connect
  # to the local host or vice versa, when the remote host is ready
  # to accept connections.
  @command /^PEER ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2}) OUT (TCP|UDP) ((?:[0-9]{1,3}\.){3}[0-9]{1,3}) ([0-9]{1,5}) ([0-9]{16})$/,
    'authenticated',
    (address, protocol, ip, port, key) ->
      port = parseInt(port) # TODO: check range
      @client.connectTo address, protocol, ip, port, key

  # Received as a responce to a CONNECT or WAITING message when remote host
  # with specified address is not found.
  @command /^PEER ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2}) MISSING$/,
    'authenticated',
    (address) ->
      @client.emit 'peerMissing', new Address(address)

  setAddress: (address) ->
    @address = new Address address
    @socket.write "ADDRESS #{address}\n"
    @setState 'addressSent'

  requestAddress: ->
    @socket.write "REQUEST\n"
    @setState 'addressRequested'

  connect: (address) ->
    @socket.write "CONNECT #{address}\n"
