foonet = require '../lib/foonet'

foonet.createConnection 8000, 'localhost', (connection) ->
  process.stdout.write 'Enter address: '
  process.stdin.resume()

  process.stdin.on 'data', (chunk) ->
    try
      connection.set_address chunk.toString('utf8', 0, chunk.length - 1)
      process.stdin.pause()
    catch e
      process.stdout.write "#{e}, try again: "