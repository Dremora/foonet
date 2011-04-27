class exports.Address
  constructor: (@address) ->
    unless /^(?:[0-9a-f]{2}\:){3}[0-9a-f]{2}$/.test @address
      throw new Error 'Error parsing address'

  toString: ->
    @address