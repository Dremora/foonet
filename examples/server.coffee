foonet = require '..'
fs = require 'fs'

fs.readFile "#{__dirname}/server_mysql_config.json", (error, data) ->
  return console.log error.message if error
  mysql_options = JSON.parse data
  foonet.createServer 8000, mysql_options, (error) ->
    console.log error.message if error
