net = require 'net'
{EventEmitter} = require 'events'

WILL = 251
WONT = 252
DO   = 253
DONT = 254
IAC  = 255

class IACState 
  constructor: ->
    @buffer = []
    @inIAC = false
    @inAction = null
    @inSB = false

  bytes: (clear = true) -> 
    bytes = new Buffer @buffer.slice 0
    @buffer = [] if clear
    return bytes

  readBytes: (bytes) ->
    @readByte b for b in bytes

  readByte: (b) ->
    if @inIAC
      if @inSB
        # 
      else
        @inAction = b
        @inIAC = false
    else if @inAction
      console.log 'action', @inAction, b
      @inAction = null
    else
      switch b
        when IAC
          @inIAC = true
        else
          @buffer = @buffer.concat b

class TelnetServer extends EventEmitter
  constructor: (socket) ->
    state = new IACState()
    socket.on 'data', (chunk) =>
      state.readBytes chunk
      data = state.bytes()
      @emit 'data', data if data.length > 0

server = net.createServer (socket) ->
  telnet = new TelnetServer socket
  telnet.on 'data', (data) ->
    console.log 'Read data: hex=', data.toString('hex'), ' ascii=', data.toString('ascii')

server.listen 8888
