#!/usr/bin/env coffee
###
(c) 2010 Stephane Alnet
Released under the AGPL3 license
###

require('ccnq3_config').get (config)->

  zappa = require 'zappa'
  zappa config.kayako_loginshare.port, config.kayako_loginshare.hostname, {config}, ->

    @use 'bodyParser'

    json_req = require 'json_req'

    kayako_error_msg = (msg) ->
      msg ?= 'Invalid Username or Password'
      """
      <?xml version="1.0" encoding="UTF-8"?>
      <loginshare>
        <result>0</result>
        <message>#{msg}</message>
      </loginshare>
      """

    @post '/loginshare': ->
      q =
        method: 'POST'
        uri: config.kayako_loginshare.login_uri
        body:
          username: @body.username
          password: @body.password

      json_req.request q, (p,cookie) =>
        if p.error?
          return @send kayako_error_msg()

        s =
          uri: config.kayako_loginshare.profile_uri
          headers:
            cookie: cookie

        json_req.request s, (r) =>
          if r.error?
            return @send kayako_error_msg("Internal Error")

          @send """
               <?xml version="1.0" encoding="UTF-8"?>
               <loginshare>
                 <result>1</result>
                 <user>
                   <usergroup>Registered</usergroup>
                   <fullname>#{r.name}</fullname>
                   <emails>
                     <email>#{r.email}</email>
                   </emails>
                   <phone>#{r.phone}</phone>
                 </user>
               </loginshare>
               """
