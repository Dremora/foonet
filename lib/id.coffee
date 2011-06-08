mysql = require './mysql'

module.exports = class Id
  constructor: (id) ->
    switch typeof id
      when 'string'
        unless matches = /^([0-9a-f]{2})\:([0-9a-f]{2})\:([0-9a-f]{2})\:([0-9a-f]{2})$/.exec id
          throw new Error 'Error parsing id'
        matches.splice(0, 1)
        @buffer = new Buffer(4)
        for i in [0...matches.length]
          @buffer[i] = 0
          for j in [0, 1]
            c = matches[i].charCodeAt(j)
            @buffer[i] |= (c - (if c > 57 then 87 else 48)) << (1 - j) * 4
      when 'number'
        @buffer = new Buffer(4)
        for i in [0...@buffer.length]
          @buffer[i] = id >> (8 * (3 - i)) & 0xFF

  toString: ->
    r = []
    for i in [0...@buffer.length]
      num = @buffer[i] >> 4
      r[i * 3] = String.fromCharCode(num + (if num < 10 then 48 else 87))
      num = @buffer[i] & 0xf
      r[i * 3 + 1] = String.fromCharCode(num + (if num < 10 then 48 else 87))
      r[i * 3 + 2] = ':' unless i == 3
    r.join('')

  toNumber: ->
    results = 0
    results += @buffer[i] << 8 * (3 - i) for i in [0...@buffer.length]
    results

  find: (callback) ->
    mysql.connection.query 'SELECT * FROM ids WHERE id = ?',
    [@toNumber()], (error, results) ->
      throw error if error
      callback(results.length > 0)

Id.create = (callback) ->
  mysql.connection.query 'INSERT INTO ids VALUES()', (error, results) ->
    throw error if error
    callback(new Id(results.insertId))
