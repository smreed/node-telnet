net = require 'net'
{TelnetServer} = require '../lib/telnet'

server = net.createServer (socket) ->

  options =
    naws: false
    ttypes: false

  telnet = new TelnetServer socket, options

  telnet.promptForSecret 'type secret:', (secret) ->
    telnet.writeLn 'Thanks!'
    socket.destroySoon()
    console.log "The secret is [#{secret}]"

server.listen 8888
