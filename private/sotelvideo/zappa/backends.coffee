###
(c) 2010 Stephane Alnet
Released under the AGPL3 license
###
req = require 'request'
querystring = require 'querystring'

exports.sql = (config,_sql,_p,cb) ->
  _uri = config.sql_db_uri
  data =
    sql: _sql
    params: _p

  options =
    method:  'POST'
    uri:     _uri
    headers: {accept:'application/json','content-type':'application/json'}
    body:    new Buffer(JSON.stringify(data))
  req options, (error,response,body) ->
    if(!error && response.statusCode == 200)
      cb(JSON.parse(body))
    else
      cb({error:error})

exports.dancer_session = (config,cookies,cb) ->
  _uri = config.dancer_session_uri
  if not cookies
    return cb({error:"No cookies"})
  id = cookies["dancer.session"]
  options =
    uri:      _uri+'/'+querystring.escape(id)
    headers:  {accept:'application/json'}
  req options, (error,response,body) ->
    if(!error && response.statusCode == 200)
      cb(JSON.parse(body))
    else
      cb({error:error})

exports.user_info = (config,user_id,cb) ->
  _uri = config.portal_couchdb_uri
  options =
    method:   'GET'
    uri:      _uri+'/'+querystring.escape(user_id)
    headers:  {accept:'application/json'}
  req options, (error,response,body) ->
    if(!error && response.statusCode == 200)
      cb(JSON.parse(body))
    else
      cb({error:error})
