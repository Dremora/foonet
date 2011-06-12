foonet = require '..'

gate = new foonet.Gate 8001, 'localhost', '9764982319465789', 9000
gate.on 'error', (error) -> console.log error.message
