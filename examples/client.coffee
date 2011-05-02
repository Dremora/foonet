foonet = require '..'
Address = require '../lib/address'

client = new foonet.Client 8000, 'localhost', (connection) ->

  connectOrWait = (chunk) ->
    try
      unless chunk.length == 1
        address = new Address(chunk.toString('utf8', 0, chunk.length - 1))
        connection.connect(address)
      process.stdin.pause()
    catch e
      process.stdout.write "Error parsing address, try again: "
      process.stdin.once 'data', connectOrWait

  getAddress = (chunk) ->
    try
      if chunk.length == 1
        connection.requestAddress()
      else
        connection.setAddress chunk.toString('utf8', 0, chunk.length - 1)
      process.stdout.write 'Input remote host address or press enter to wait: '
      process.stdin.once 'data', connectOrWait
    catch e
      process.stdout.write "#{e}, try again: "
      process.stdin.once 'data', getAddress

  process.stdout.write 'Input address or press enter to get one: '
  process.stdin.resume()
  process.stdin.once 'data', getAddress

  client.on 'peerMissing', (address) ->
    console.log "Peer #{address} doesn't exist"
    process.stdout.write 'Input remote host address or press enter to wait: '
    process.stdin.resume()
    process.stdin.once 'data', connectOrWait

  client.on 'peer', (address, socket) ->
    console.log "Connection established with #{address}"

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

      process.stdout.write 'Input remote host address or press enter to wait: '
      process.stdin.once 'data', connectOrWait
