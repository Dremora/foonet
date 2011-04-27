mysql = require 'mysql'

exports.createConnection = (mysql_options, cb) ->
  connection = new mysql.Client mysql_options
  exports.connection = connection
  connection.connect cb
