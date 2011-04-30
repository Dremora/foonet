foonet = require '..'

new foonet.Client 8000, 'localhost', (connection) ->
  process.stdout.write 'Input address or press enter to get one: '
  process.stdin.resume()

  process.stdin.on 'data', (chunk) ->
    try
      if chunk.length == 1
        connection.request_address()
      else
        connection.set_address chunk.toString('utf8', 0, chunk.length - 1)
      process.stdin.pause()
    catch e
      process.stdout.write "#{e}, try again: "
