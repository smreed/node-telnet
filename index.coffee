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
            chunk = @bytes()
            # TODO : assert last byte is IAC
            @emit 'iac_sb', chunk.slice 0, chunk.length - 1
            @inIAC = false
            @inAction = null
          else
            @buffer.push b
        else
          @buffer.push @inAction
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

commandIs = (command, tests...) ->
  result = true
  result &= command[i] is v for i,v of tests
  return result

sendCommand = (socket, command...) ->
  socket.write new Buffer command

commandName = (b) ->
  names[b] ? b

class TelnetServer extends EventEmitter
  constructor: (socket, options = {}) ->
    @echo = false
    @ttypes = []
    state = new IACState()

    # socket.setNoDelay true

    onCommand = (command) =>
      console.log 'command', (commandName b for b in command)
      if commandIs command, constants.WONT, constants.NAWS
        options.setClientSize? {width: -1, height: -1}
      #if commandIs command, constants.WILL, constants.NAWS
        # do nothing yet
      if commandIs command, constants.NAWS
        width = command[1] << 8
        width |= command[2]
        height = command[3] << 8
        height |= command[4]
        options.setClientSize? {width: width, height: height}
      if commandIs command, constants.DO, constants.ECHO
        @echo = true
        sendCommand socket, constants.IAC, constants.WILL, constants.ECHO
      if commandIs command, constants.DONT, constants.ECHO
        @echo = false
        sendCommand socket, constants.IAC, constants.WONT, constants.ECHO
      if commandIs command, constants.DO, constants.SGA
        sendCommand socket, constants.IAC, constants.WILL, constants.SGA
      if commandIs command, constants.WILL, constants.TTYPE
        sendCommand socket, constants.IAC, constants.SB, constants.TTYPE, constants.ECHO, constants.IAC, constants.SE
      if commandIs command, constants.TTYPE, constants.BINARY
        ttype = command.slice(2, command.length).toString 'ascii'
        if @ttypes[@ttypes.length-1] is ttype
          console.log @ttypes
        else
          @ttypes.push ttype
          sendCommand socket, constants.IAC, constants.SB, constants.TTYPE, constants.ECHO, constants.IAC, constants.SE


    state.on 'iac', onCommand
    state.on 'iac_sb', onCommand

    socket.on 'data', (chunk) ->
      state.readBytes chunk
    
    state.on 'data', (chunk) =>
      @emit 'data', chunk
    
    state.on 'data', (chunk) =>
      if @echoOn()
        socket.write chunk

    if typeof options.setClientSize is 'function'
      sendCommand socket, constants.IAC, constants.DO, constants.NAWS

    sendCommand socket, constants.IAC, constants.DO, constants.TTYPE 

  echoOn: -> @echo
  echoOff: -> !@echo

server = net.createServer (socket) ->
  telnet = new TelnetServer socket,
    setClientSize: (dim) -> 
      console.log "Client reports dimensions of w=#{dim.width},h=#{dim.height}"
      for n in [1..dim.height]
        socket.write new Buffer '\r\n'
        socket.write new Buffer "#{(n - 1)%10}" for i in [1..dim.width]
  telnet.on 'data', (data) ->
    console.log 'data:', data.toString 'ascii'

server.listen 8888
