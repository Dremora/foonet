foonet = require '..'

new foonet.Gate 8001, 'localhost', '9764982319465789', 9000, (error) ->
  console.log error.message
