net = require 'net'
{TelnetServer} = require '../lib/telnet'

server = net.createServer (socket) ->

  options =
    setClientSize: (dim) -> 
      console.log "Client reports dimensions of w=#{dim.width},h=#{dim.height}"
      for n in [1..dim.height]
        socket.write new Buffer '\r\n'
        socket.write new Buffer "#{(n - 1)%10}" for i in [1..dim.width]

  telnet = new TelnetServer socket, options

  telnet.on 'data', (data) ->
    console.log 'data:', data.toString 'ascii'

server.listen 8888
