Address = require('./address')
CommandConnection = require './command_connection'

module.exports = class ClientToServerConnection extends CommandConnection
  states:
    notAuthenticated: 'notAuthenticated'
    addressRequested: 'addressRequested'
    addressSent: 'addressSent'
    authenticated: 'authenticated'

  actions:
    parseAddress: [
      /^ADDRESS ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2})$/
      (address) ->
        @address = new Address address
        console.log "Received address #{address}"
        @socket.write "CAPABILITIES TCP #{@client.port}\n"
        @setState @states.authenticated
    ]

    authenticated: [
      /^AUTHENTICATED$/
      ->
        console.log 'Authenticated'
        @socket.write "CAPABILITIES TCP #{@client.port}\n"
        @setState @states.authenticated
    ]

    notAuthenticated: [
      /^NOT AUTHENTICATED$/
      ->
        console.log 'Not authenticated'
        @setState @states.notAuthenticated
    ]

    # Received when a remote host with specified `address' wants to connect
    # to the local host or vice versa, when local host should wait for
    # an incoming connection from the remote host.
    peerIn: [
      /^PEER ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2}) IN (TCP|UDP) ((?:[0-9]{1,3}\.){3}[0-9]{1,3})$/
      (address, protocol, ip) ->
        key = Math.floor(Math.random() * 10000000000000000).toString()
        while key.length < 16
          key = '0' + key
        @client.acceptFrom address, protocol, ip, key
        @socket.write "WAITING #{address} #{key}\n"
    ]

    # Received when a remote host with specified `address' wants to connect
    # to the local host or vice versa, when the remote host is ready
    # to accept connections.
    peerOut: [
      /^PEER ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2}) OUT (TCP|UDP) ((?:[0-9]{1,3}\.){3}[0-9]{1,3}) ([0-9]{1,5}) ([0-9]{16})$/
      (address, protocol, ip, port, key) ->
        port = parseInt(port) # TODO: check range
        @client.connectTo address, protocol, ip, port, key
    ]

    # Received as a responce to a CONNECT or WAITING message when remote host
    # with specified address is not found.
    peerMissing: [
      /^PEER ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2}) MISSING$/
      (address) ->
        @client.emit 'peerMissing', new Address(address)
    ]

  transitions:
    notAuthenticated: []
    addressRequested: [
      'parseAddress'
    ]
    addressSent: [
      'authenticated'
      'notAuthenticated'
    ]
    authenticated: [
      'peerIn'
      'peerOut'
      'peerMissing'
    ]

  setAddress: (address) ->
    @address = new Address address
    @socket.write "ADDRESS #{address}\n"
    @setState @states.addressSent

  requestAddress: ->
    @socket.write "REQUEST\n"
    @setState @states.addressRequested

  connect: (address) ->
    @socket.write "CONNECT #{address}\n"
