
net         = require 'net'
querystring = require 'querystring'
util        = require 'util'

parse_header_text = (header_text) ->
  header_lines = header_text.split("\n")
  headers = {}
  for line in header_lines
    do (line) ->
      [name,value] = line.split /: /, 2
      headers[name] = value

  # Decode headers: in the case of the "connect" command,
  # the headers are all URI-encoded.
  if headers['Reply-Text']?[0] is '%'
    for name of headers
      headers[name] = querystring.unescape(headers[name])

  return headers

class eslParser
  constructor: (@socket) ->
    @body_left = 0
    @buffer = ""

  capture_body: (data) ->
    if data.length < @body_left
      @buffer    += data
      @body_left -= data.length
    else
      body = @buffer + data.substring(0,@body_left)
      @buffer = data.substring(@body_left)
      @body_left = 0
      @process @headers, body
      @headers = {}

  capture_headers: (data) ->
    header_end = data.indexOf("\n\n")

    if header_end < 0
      @buffer += data
      return

    # Consume the headers
    header_text = @buffer + data.substring(0,header_end)
    @buffer = data.substring(header_end+2)
    # Parse the header lines
    @headers = parse_header_text(header_text)
    # Figure out whether a body is expected
    if @headers["Content-Length"]
      @body_left = @headers["Content-Length"]
      [@buffer,data] = ["",@buffer]
      @capture_body(data)
    else
      @process @headers
      @headers = {}

  on_data: (data) ->

    # Capture the body as needed
    if @body_left > 0
      return @capture_body data
    else
      return @capture_headers data

  on_end: () ->


class eslRequest
  constructor: (@headers,@body) ->

class eslResponse
  constructor: (@socket) ->

  # send (string,[hash],function(req,res))

  send: (command,args,cb) ->
      [args,cb] = [null,args] if typeof(args) is 'function'

      # Make sure we are the only one receiving command replies
      @socket.removeAllListeners('esl_command_reply')
      if cb?
        @on 'esl_command_reply', (req,res) ->
          cb(req,res)

      @socket.write "#{command}\n"
      if args?
        for key, value of args
          @socket.write "#{key}: #{value}\n"
      @socket.write "\n"

  on: (event,listener) -> @socket.on(event,listener)

  end: () -> @socket.end()

  # Channel-level commands:

  api: (command,cb) ->
    @send "api #{command}", null, cb

  bgapi: (command,cb) ->
    @send "api #{command}", null, (req,res) ->
      r = res.header['Reply-Text']?.match /\+OK Job-UUID: (.+)$/
      cb r[1]

  # Event reception and filtering

  event_json: (events...,cb) ->
    @send "event json #{events.join(' ')}", null, cb

  nixevent: (events...,cb) ->
    @send "nixevent #{events.join(' ')}", null, cb

  noevents: (cb) ->
    @send "noevents", null, cb

  filter: (header,value,cb) ->
    @send "filter #{header} #{value}", null, cb

  filter_delete: (header,value,cb) ->
    if value?
      @send "filter #{header} #{value}", null, cb
    else
      @send "filter #{header}", null, cb

  sendevent: (event_name,args,cb) ->
    @send "sendevent #{event_name}", args, cb

  auth: (password,cb)       -> @send "auth #{password}", null, cb

  connect: (cb)             -> @send "connect", null, cb    # Outbound mode

  linger: (cb)              -> @send "linger", null, cb     # Outbound mode

  exit: (cb)                -> @send "exit", null, cb

  log: (level,cb) ->
    [level,cb] = [null,level] if typeof level is 'function'
    if level?
      @send "log #{level}", null, cb
    else
      @send "log", null, cb

  nolog: (cb)                 -> @send "nolog", null, cb


  # Send Message (to a UUID)

  sendmsg_uuid: (uuid,command,args,cb) ->
    options = args
    options['call-command'] = command
    execute_text = if uuid? then "sendmsg #{uuid}" else 'sendmsg'
    @send execute_text, options, cb

  # Same, assuming server/outbound ESL mode:

  sendmsg: (command,args,cb) -> sendmsg_uuid null, command, args, cb

  # Execute an application for the given UUID (in client mode)

  execute_uuid: (uuid,app_name,app_arg,cb) ->
    options =
      'execute-app-name': app_name
      'execute-app-arg':  app_arg
    @sendmsg uuid, 'execute', options, cb

  hangup_uuid: (uuid,hangup_cause,cb) ->
    hangup_cause ?= 'NORMAL_UNSPECIFIED'
    options =
      'hangup-cause': hangup_cause
    @sendmsg uuid, 'hangup', options, cb

  unicast_uuid: (uuid,args,cb) ->
    @sendmsg uuid, 'unicast', args, cb

  # nomedia_uuid:

  # Execute an application for the current UUID (in server/outbound mode)

  execute: (app_name,app_arg,cb)  -> @execute_uuid null, app_name, app_arg, cb

  hangup: (hangup_cause,cb)       -> @hangup_uuid  null, hangup_cause, cb

  unicast: (args,cb)              -> @unicast_uuid null, args, cb

  # nomedia:


# This is modelled after Node.js' http.js

connectionListener= (socket) ->
  socket.setEncoding('ascii')
  parser = new eslParser socket
  socket.on 'data', (data) ->  parser.on_data(data)
  socket.on 'end',  ()     ->  parser.on_end()
  parser.process = (headers,body) ->
    switch headers['Content-Type']
      when 'auth/request'
        event = 'esl_auth_request'
      when 'command/reply'
        event = 'esl_command_reply'
        # Apparently a bug in the response to "connect"
        if headers['Event-Name'] is 'CHANNEL_DATA'
          body = headers
          headers = {}
          for n in ['Content-Type','Reply-Text','Socket-Mode','Control']
            headers[n] = body[n]
            delete body[n]
      when 'text/event-json'
        try
          body = JSON.parse(body)
        catch error
          util.log "#{error} in #{body}"
          return
        event = 'esl_event'
      when 'text/event-plain'
        body = parse_header_text(body)
        event = 'esl_event'
      when 'log/data'
        event = 'esl_log_data'
      when 'text/disconnect-notice'
        event = 'esl_disconnect_notice'
      else
        event = headers['Content-Type']
    req = new eslRequest headers,body
    res = new eslResponse socket
    # util.log "emit #{event}"+util.inspect(req,res)
    socket.emit event, req, res
  # Get things started
  @emit 'esl_connect', new eslResponse socket

class eslServer extends net.Server
  constructor: (requestListener) ->
    @on 'esl_connect', requestListener
    @on 'connection', connectionListener
    super()

exports.createServer = (requestListener) -> return new eslServer(requestListener)

class eslClient extends net.Socket
  constructor: (host,port) ->
    @on 'connect', connectionListener
    super port, host

exports.createClient = (host,port) -> return new eslClient(host,port)


# Examples:
###

client =  createClient(host,port)
client.on 'esl_auth_request', (req,res) ->
    res.send "auth #{auth}", () ->
      res.send 'event json HEARTBEAT'

###

