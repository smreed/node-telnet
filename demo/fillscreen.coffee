net = require 'net'
{TelnetServer} = require '../lib/telnet'

newline = new Buffer '\r\n'

server = net.createServer (socket) ->

  options =
    naws: true
    ttypes: false


  onResize = (dim) -> 
    console.log "Client reports dimensions of w=#{dim.width},h=#{dim.height}"
    for n in [1..dim.height]
      socket.write newline
      socket.write new Buffer "#{(n - 1)%10}" for i in [1..dim.width]

  telnet = new TelnetServer socket, options

  telnet.on 'window_size', onResize
  telnet.on 'data', (data) -> console.log 'data:', data.toString 'ascii'

server.listen 8888
