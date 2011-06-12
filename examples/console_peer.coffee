foonet = require '..'
Id = require '../lib/id'
config_loaded = require './config_loader'

config_loaded.load (config) ->
  peer = new foonet.Peer config.master.peerPort, config.master.host
  peer.on 'error', (error) -> console.log error.message
  peer.on 'connect', (connection) => masterConnection(connection, peer)

masterConnection = (connection, peer) ->
  getId = (chunk) ->
    try
      if chunk.length == 1
        connection.requestId()
      else
        connection.setId chunk.toString('utf8', 0, chunk.length - 1)
    catch e
      process.stdout.write "#{e}, try again: "
      process.stdin.once 'data', getId

  process.stdout.write 'Input id or press enter to get one: '
  process.stdin.resume()
  process.stdin.once 'data', getId

  connectOrWait = (chunk) ->
    try
      unless chunk.length == 1
        id = new Id(chunk.toString('utf8', 0, chunk.length - 1))
        console.log chunk.toString('utf8', 0, chunk.length - 1)
        connection.connect(id)
      process.stdin.pause()
    catch e
      process.stdout.write "Error parsing id, try again: "
      process.stdin.once 'data', connectOrWait

  peer.on 'ready', ->
    process.stdout.write 'Input remote host id or press enter to wait: '
    process.stdin.once 'data', connectOrWait

  peer.on 'peerMissing', (id) ->
    console.log "Peer #{id} doesn't exist"
    process.stdout.write 'Input remote host id or press enter to wait: '
    process.stdin.resume()
    process.stdin.once 'data', connectOrWait

  peer.on 'peer', (id, socket) ->
    console.log "Connection established with #{id}"

    abortConnection = ->
      socket.end()

    process.once 'SIGINT', abortConnection

    sendData = (chunk) ->
      socket.write chunk

    process.stdin.resume()
    process.stdin.on 'data', sendData

    socket.on 'data', (chunk) ->
      process.stdout.write chunk.toString('utf8')

    socket.on 'close', ->
      process.stdin.removeListener('data', sendData)
      process.removeListener('SIGINT', abortConnection)
      console.log 'Connection closed'

      process.stdout.write 'Input remote host id or press enter to wait: '
      process.stdin.once 'data', connectOrWait
