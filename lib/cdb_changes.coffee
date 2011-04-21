###
# (c) 2010 Stephane Alnet
# Released under the GPL3 license
###

cdb = require './cdb.coffee'

util = require 'util'
querystring = require 'querystring'

# Reference for request: https://github.com/mikeal/node-utils/tree/master/request

# Changes API: http://wiki.apache.org/couchdb/HTTP_database_API#Changes
# and also:    http://guide.couchdb.org/draft/notifications.html


cdb_changes = exports

cdb_changes.monitor = (cdb_uri,filter_name,since,cb)->
  util.log "Starting"

  db = cdb.new (cdb_uri)

  # Stream to receive the data from CouchDB
  parser = new process.EventEmitter()

  parser.buffer = ""

  parser.writable = true

  parser.write = (chunk,encoding) ->
    util.log "Got chunk #{chunk}"
    parser.buffer += chunk.toString(encoding)

    d = parser.buffer.split("\n")
    while d.length > 1
      line = d.shift()
      util.log "Processing line #{line}"

      try
        p = JSON.parse line
      if p?.id?
        db.get p.id, cb

    parser.buffer = d[0]

    return true

  parser.end = ->
    util.log("#{cdb_uri} closed, attempting restart")
    # Automatically restart
    cdb_changes.monitor(cdb_uri,filter_name,since,cb)

  # Send the request

  options =
    uri: '_changes?feed=continuous&heartbeat=10000'

  options.uri += "&filter=#{querystring.escape(filter_name)}" if filter_name?
  options.uri += "&since=#{querystring.escape(since)}"        if since?

  cdb_stream = db.req options, (r) ->
    if r.error?
      util.log(r.error)

  cdb_stream.pipe(parser)
