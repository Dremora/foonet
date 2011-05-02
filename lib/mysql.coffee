mysql = require 'mysql'

exports.createConnection = (mysqlOptions, cb) ->
  connection = new mysql.Client mysqlOptions
  exports.connection = connection
  connection.connect cb
