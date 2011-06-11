mysql = require './mysql'
net = require 'net'
MasterToPeerConnection = require './master_to_peer_connection'

module.exports = class Master
  constructor: (port, mysqlOptions, callback) ->

    # Hash with authenticated peers
    @peers = {}

    # Fired when a new peer is connected
    peerHandler = (socket) =>
      peer = new MasterToPeerConnection socket

      peer.on 'id', (id) =>
        if @peers[id]
          peer.notAuthenticated()
        else id.find (exists) =>
          if exists
            peer.setId(id)
            peer.authenticated()
          else
            peer.notAuthenticated()

      peer.on 'setId', (id) =>
        @peers[id] = peer
        console.log "Peer #{id} identified"
        peer.on 'close', =>
          delete @peers[id]
          console.log "Peer #{id} quit"

      peer.on 'waiting', (id, key) =>
        if other = @peers[id]
          other.peerOut peer, key
        else
          peer.peerMissing id

      peer.on 'connect', (id) =>
        if other = @peers[id]
          # TCP connection is established if at least one of peers supports it
          if other.supports 'incomingTCP'
            other.peerIn peer
          else if peer.supports 'incomingTCP'
            peer.peerIn other
          # If both peers don't support TCP, fallback to UDP hole punching
          else
            throw new Error 'Not implemented' # TODO
        else
          peer.peerMissing id

    mysql.createConnection mysqlOptions, (error) ->
      return callback(error) if error
      server = net.createServer(peerHandler)


      # Error handling - currently id in use only
      server.on 'error', (error) ->
        if error.code == 'EADDRINUSE'
          callback(error)
        else throw error

      # Begin listening
      server.listen port, ->
        console.log "Master running at localhost:#{port}"
        callback()
