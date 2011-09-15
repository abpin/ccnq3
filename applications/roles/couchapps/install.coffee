#!/usr/bin/env coffee

couchapp = require 'couchapp'
cdb = require 'cdb'

# Load Configuration
config = require('ccnq3_config').config

# Set the security object for the _users database.
users = cdb.new config.users.couchdb_uri
users.security (p)->
  p.admins ||= {}
  p.admins.roles ||= []
  p.admins.roles.push("users_admin")  if p.admins.roles.indexOf("users_admin") < 0
  p.readers ||= {}
  p.readers.roles ||= []
  p.readers.roles.push("users_writer") if p.readers.roles.indexOf("users_writer") < 0
  p.readers.roles.push("users_reader") if p.readers.roles.indexOf("users_reader") < 0

# Installation
uri = config.users.couchdb_uri
couchapp.createApp require("./users"), uri, (app)-> app.push()
