{EventEmitter} = require 'events'

constants =
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
  buffer = new Buffer command
  socket.write buffer, 'binary'

commandName = (b) ->
  names[b] ? b

defaultOptions =
  naws: true
  ttypes: true

class TelnetServer extends EventEmitter

  # 
  # options.naws = true to negotiate about window size (default: true)
  # options.ttypes = true to query for terminal types (default: true)
  #
  constructor: (@socket, @options = defaultOptions) ->
    @echo = false
    @ttypes = []
    @state = new IACState()

    onCommand = (command) =>
      # console.log 'command', (commandName b for b in command)

      if @options.naws and commandIs command, constants.WONT, constants.NAWS
        @clientDimensions = {width: -1, height: -1}
        @emit 'window_size', @clientDimensions

      if commandIs command, constants.WILL, constants.NAWS
        doOrDoNot = if @options.naws then constants.DO else contants.DONT
        sendCommand socket, constants.IAC, doOrDoNot, constants.NAWS

      if commandIs command, constants.NAWS
        width = command[1] << 8
        width |= command[2]
        height = command[3] << 8
        height |= command[4]
        @clientDimensions = {width: width, height: height}
        @emit 'window_size', @clientDimensions

      if commandIs command, constants.DO, constants.ECHO
        @echo = true
        @emit 'echo', @echo
        sendCommand socket, constants.IAC, constants.WILL, constants.ECHO

      if commandIs command, constants.DONT, constants.ECHO
        @echo = false
        @emit 'echo', @echo
        sendCommand socket, constants.IAC, constants.WONT, constants.ECHO

      if commandIs command, constants.DO, constants.SGA
        sendCommand socket, constants.IAC, constants.WILL, constants.SGA

      if commandIs command, constants.WILL, constants.TTYPE
        sendCommand socket, constants.IAC, constants.SB, constants.TTYPE, constants.ECHO, constants.IAC, constants.SE

      if commandIs command, constants.TTYPE, 0 
        ttype = command.slice(2, command.length).toString 'ascii'
        if @ttypes[@ttypes.length-1] is ttype
          @emit 'ttypes', @ttypes
        else
          @ttypes.push ttype
          sendCommand socket, constants.IAC, constants.SB, constants.TTYPE, constants.ECHO, constants.IAC, constants.SE

    @state.on 'iac', onCommand
    @state.on 'iac_sb', onCommand

    socket.on 'data', (chunk) =>
      @state.readBytes chunk
    
    @state.on 'data', (chunk) =>
      @emit 'data', chunk
    
    @state.on 'data', (chunk) =>
      if @echoOn()
        socket.write chunk

    sendCommand socket, constants.IAC, constants.DO, constants.NAWS if @options.naws
    sendCommand socket, constants.IAC, constants.DO, constants.TTYPE  if @options.ttypes

  echoOn: -> @echo
  clientTerminalTypes: -> @ttypes
  clientWindowSize: -> @clientDimensions

  promptForSecret: (prompt, callback) ->
    sendCommand @socket, constants.IAC, constants.WILL, constants.ECHO
    @state.removeAllListeners 'data'
    @state.once 'data', (secret) =>
      secret = secret.toString 'utf8'
      secret = secret.replace c, '' for c in ['\r', '\n']
      @socket.write '\r\n'
      @state.on 'data', (chunk) =>
        @emit 'data', chunk
      sendCommand @socket, constants.IAC, constants.WONT, constants.ECHO
      callback secret 
    @socket.write prompt

  writeLn: (line) ->
    @socket.write line
    @socket.write '\r\n'

module.exports.TelnetServer = TelnetServer
