foonet = require '..'
fs = require 'fs'

fs.readFile "#{__dirname}/master_mysql_config.json", (error, data) ->
  return console.log error.message if error
  mysqlOptions = JSON.parse data
  new foonet.Master 8000, 8001, mysqlOptions, '9764982319465789', (error) ->
    console.log error.message if error
