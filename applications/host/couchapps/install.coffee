#!/usr/bin/env coffee

couchapp = require 'couchapp'
cdb = require 'cdb'

push_script = (uri,script,cb) ->
  couchapp.createApp require("./#{script}"), uri, (app)-> app.push(cb)

cfg = require 'ccnq3_config'
cfg.get (config) ->

  usercode_uri = config.usercode?.couchdb_uri
  if usercode_uri?
    push_script usercode_uri, 'usercode'

  provisioning_uri = config.provisioning?.couchdb_uri
  if provisioning_uri?
    push_script provisioning_uri, 'main'
