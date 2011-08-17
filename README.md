Introduction
========

This library provides a small wrapper around TCP sockets that handles some basic elements of the Telnet specification, such as option negotiation. Both client and server wrappers are planned, the library only provides a Server wrapper at this time.

Server Features
========

* Negotiate About Window Size (NAWS) - receive events when the client informs your server of its terminal height and width.
* Terminal Type - Enumerate available client terminal types.
* Character Mode / Echo - Server supports character mode and will echo back if the client requests it.

Planned Features
========

* Password Prompting - Disable client echo from the server so they can enter sensitive information (although we're talking Telnet here so don't go crazy).

Example Server
========

Example code in coffee-script that reports the client height-width.

```coffeescript
net = require 'net'
{TelnetServer} = require '../lib/telnet'

server = net.createServer (socket) ->
  options =
    setClientSize: (dim) ->
      console.log "width=#{dim.width}, height=#{dim.height}"
      socket.end 'Thanks!'

  telnet = new TelnetServer socket, options

server.listen 8888
```
