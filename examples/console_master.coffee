foonet = require '..'
fs = require 'fs'

fs.readFile "#{__dirname}/master_mysql_config.json", (error, data) ->
  return console.log error.message if error
  mysqlOptions = JSON.parse data
  new foonet.Master 8000, mysqlOptions, (error) ->
    console.log error.message if error
