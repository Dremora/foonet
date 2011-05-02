Address = require('./address')
CommandConnection = require './command_connection'

module.exports = class ClientToServerConnection extends CommandConnection
  states:
    not_authenticated: 'not_authenticated'
    address_requested: 'address_requested'
    address_sent: 'address_sent'
    authenticated: 'authenticated'

  actions:
    parse_address: [
      /^ADDRESS ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2})$/
      (address) ->
        @address = new Address address
        console.log "Received address #{address}"
        @socket.write "CAPABILITIES TCP #{@client.port}\n"
        @set_state @states.authenticated
    ]

    authenticated: [
      /^AUTHENTICATED$/
      ->
        console.log 'Authenticated'
        @socket.write "CAPABILITIES TCP #{@client.port}\n"
        @set_state @states.authenticated
    ]

    not_authenticated: [
      /^NOT AUTHENTICATED$/
      ->
        console.log 'Not authenticated'
        @set_state @states.not_authenticated
    ]

    # Received when a remote host with specified `address' wants to connect
    # to the local host or vice versa, when local host should wait for
    # an incoming connection from the remote host.
    peer_in: [
      /^PEER ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2}) IN (TCP|UDP) ((?:[0-9]{1,3}\.){3}[0-9]{1,3})$/
      (address, protocol, ip) ->
        key = Math.floor(Math.random() * 10000000000000000).toString()
        while key.length < 16
          key = '0' + key
        @client.accept_from address, protocol, ip, key
        @socket.write "WAITING #{address} #{key}\n"
    ]

    # Received when a remote host with specified `address' wants to connect
    # to the local host or vice versa, when the remote host is ready
    # to accept connections.
    peer_out: [
      /^PEER ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2}) OUT (TCP|UDP) ((?:[0-9]{1,3}\.){3}[0-9]{1,3}) ([0-9]{1,5}) ([0-9]{16})$/
      (address, protocol, ip, port, key) ->
        port = parseInt(port) # TODO: check range
        @client.connect_to address, protocol, ip, port, key
    ]

    # Received as a responce to a CONNECT or WAITING message when remote host
    # with specified address is not found.
    peer_missing: [
      /^PEER ((?:[0-9a-f]{2}\:){3}[0-9a-f]{2}) MISSING$/
      (address) ->
        @client.emit 'peerMissing', new Address(address)
    ]

  transitions:
    not_authenticated: []
    address_requested: [
      'parse_address'
    ]
    address_sent: [
      'authenticated'
      'not_authenticated'
    ]
    authenticated: [
      'peer_in'
      'peer_out'
      'peer_missing'
    ]

  set_address: (address) ->
    @address = new Address address
    @socket.write "ADDRESS #{address}\n"
    @set_state @states.address_sent

  request_address: ->
    @socket.write "REQUEST\n"
    @set_state @states.address_requested

  connect: (address) ->
    @socket.write "CONNECT #{address}\n"
