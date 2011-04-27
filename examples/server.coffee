foonet = require '..'
fs = require 'fs'

fs.readFile "#{__dirname}/server_mysql_config.json", (error, data) ->
  if error
    console.log error.message
    return
  mysql_options = JSON.parse data
  foonet.createServer 8000, mysql_options
