fs = require 'fs'

exports.load = (callback) ->
  fs.readFile "#{__dirname}/config.json", (error, data) ->
    return console.log error.message if error
    callback(JSON.parse data)
