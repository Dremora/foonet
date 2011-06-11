module.exports = class Key
  @generate: ->
    key = Math.floor(Math.random() * 10000000000000000).toString()
    while key.length < 16
      key = '0' + key
    key
