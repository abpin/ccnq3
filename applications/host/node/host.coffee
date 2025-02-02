#!/usr/bin/env coffee
###
A library to install a manager host in a ccnq3 system.
(c) 2010 Stephane Alnet
Released under the AGPL3 license
###

# Create a username for the new host's main process so that it can bootstrap its own installation.
util = require 'util'
crypto = require 'crypto'

make_id = (t,n) -> [t,n].join ':'

host_username = (n) -> "host@#{n}"

sha1_hex = (t) ->
  return crypto.createHash('sha1').update(t).digest('hex')

exports.create_user = (users_db,hostname,cb) ->
  username = host_username hostname

  salt = sha1_hex "a"+Math.random()
  password = sha1_hex "a"+Math.random()

  p =
    _id: "org.couchdb.user:#{username}"
    type: "user"
    name: username
    roles: ["host"]
    salt: salt
    password_sha: sha1_hex password+salt

  users_db.put p, (r)->
    if r.error?
      util.log util.inspect r
      throw "Creating user record for #{username}"

    util.log "Created user record for #{username}"
    cb? password


exports.update_config = (provisioning_uri,provisioning_db,password,config,cb) ->
  # config.type = "host"
  # config.host = hostname
  # config._id  = make_id 'host', hostname

  username = host_username config.host

  # Update the provisioning URI to use the host's new username and password.
  url = require 'url'
  q = url.parse provisioning_uri
  delete q.href
  delete q.host
  q.auth = "#{username}:#{password}"

  config.provisioning ?= {}
  config.provisioning.host_couchdb_uri = url.format q
  config.provisioning.local_couchdb_uri = provisioning_uri

  provisioning_db.put config, (r)->
    if r.error?
      util.log util.inspect r
      throw "Creating provisioning record for #{username}"

    util.log "Created provisioning record for #{username}"
    cb? config
