net = require 'net'
{EventEmitter} = require 'events'

constants =
  BINARY: 0    # Binary
  ECHO: 1      # Echo
  SGA: 3       # Suppress Go Ahead
  TTYPE: 24    # Terminal Type
  NAWS: 31     # Negotiate About Window Size
  LINEMODE: 34 # Line mode
  SE: 240      # Subnegotiation end
  NOP: 241     # No Operation
  DM: 242      # Data Mark
  BRK: 243     # Break
  IP: 244      # Interrupt Process
  AO: 245      # Abort Output
  AYT: 246     # Are You There
  EC: 247      # Erase Character
  EL: 248      # Erase Line
  GA: 249      # Go Ahead
  SB: 250      # Subnegotiation
  WILL: 251
  WONT: 252
  DO: 253
  DONT: 254
  IAC: 255

names = {}
names[v] = k for k,v of constants 

class IACState extends EventEmitter
  constructor: ->
    @buffer = []
    @inIAC = false
    @inSB = false
    @inAction = null

  bytes: (clear = true) -> 
    bytes = new Buffer @buffer.slice 0
    @buffer = [] if clear
    return bytes

  readBytes: (bytes) ->
    @readByte b for b in bytes
    chunk = @bytes()
    @emit 'data', chunk if chunk.length

  readByte: (b) ->
    if @inIAC
      if @inAction
        if @inAction is constants.SB
          if b is constants.SE
            @emit 'iac_sb', @bytes()
            @inSB = false
          else
            @buffer.push b
        else
          @buffer.push b
          @emit 'iac', @bytes()
          @inAction = null
          @inIAC = false
      else
        @inAction = b
    else if b is constants.IAC
      chunk = @bytes()
      @emit 'data', chunk if chunk.length
      @inIAC = true
    else
      @buffer.push b

class TelnetServer extends EventEmitter
  constructor: (socket) ->
    state = new IACState()
    state.on 'data', (chunk) =>
      @emit 'data', chunk
    state.on 'iac', (command) ->
      console.log 'command', (names[b] for b in command)
    state.on 'iac_sb', (command) ->
      console.log 'got iac sb hex=', command.toString('hex'), ' ascii=', command.toString('ascii')
    socket.on 'data', (chunk) =>
      state.readBytes chunk

server = net.createServer (socket) ->
  telnet = new TelnetServer socket
  telnet.on 'data', (data) ->
    console.log 'Read data: hex=', data.toString('hex'), ' ascii=', data.toString('ascii')

server.listen 8888
