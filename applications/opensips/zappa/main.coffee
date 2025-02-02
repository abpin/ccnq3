#!/usr/bin/env coffee
###
(c) 2010 Stephane Alnet
Released under the AGPL3 license
###

util = require 'util'
qs = require 'querystring'
request = require 'request'

make_id = (t,n) -> [t,n].join ':'

require('ccnq3_config').get (config)->

  config.opensips_proxy ?= {}
  config.opensips_proxy.port ?= 34340
  config.opensips_proxy.hostname ?= "127.0.0.1"
  config.opensips_proxy.usrloc_uri ?= "http://127.0.0.1:5984/location"

  zappa = require 'zappa'
  zappa config.opensips_proxy.port, config.opensips_proxy.hostname, {config}, ->

    @use 'bodyParser'

    column_types =
      location:
        username:'string'
        domain:'string'
        contact:'string'
        received:'string'
        path:'string'
        expires:'date'
        q:'double'
        callid:'string'
        cseq:'int'
        last_modified:'date'
        flags:'int'
        cflags:'int'
        user_agent:'string'
        socket:'string'
        methods:'int'

    unquote_value = (t,x) ->

      if not x?
        return x

      if t is 'int'
        return parseInt(x)
      if t is 'double'
        return parseFloat(x)
      # Not sure what the issue is, but we're getting garbage at the end of dates.
      if t is 'date'
        d = new Date(x)
        # Format expected by db_str2time() in db/db_ut.c
        # TODO: This requires opensips to be started in UTC, assuming
        #       toISOString() outputs using UTC (which it does in Node.js 0.4.11).
        return d.toISOString().replace 'T', ' '

      # string, blob, ...
      return x.toString()

    unquote_params = (k,v,table)->
      doc = {}
      names = k.split ','
      values = v.split ','
      types = column_types[table]

      doc[names[i]] = unquote_value(types[names[i]],values[i]) for i in [0..names.length]

      return doc

    _request = (that,loc) ->
      request(loc).pipe(that.response)

    _pipe = (that,base,t,id) ->
      loc = "#{base}/_design/opensips/_show/format/#{qs.escape id}?t=#{t}&c=#{qs.escape that.query.c}"
      _request that, loc

    pipe_req = (that,t,id) ->
      _pipe that, config.provisioning.local_couchdb_uri, t, id

    pipe_loc_req = (that,t,id) ->
      _pipe that, config.opensips_proxy.usrloc_uri, t, id

    _list = (that,base,t,view) ->
      loc = "#{base}/_design/opensips/_list/format/#{view}?t=#{t}&c=#{qs.escape that.query.c}"
      request(loc).pipe(that.response)

    pipe_list = (that,t,view) ->
      _list that, config.provisioning.local_couchdb_uri, t, view

    pipe_loc_list = (that,t,view) ->
      _list that, config.opensips_proxy.usrloc_uri, t, view

    _list_key = (that,base,t,view,key) ->
      key = "\"#{key}\""
      loc = "#{base}/_design/opensips/_list/format/#{view}?t=#{t}&c=#{qs.escape that.query.c}&key=#{qs.escape key}"
      request(loc).pipe(that.response)

    pipe_list_key = (that,t,view,key) ->
      _list_key that, config.provisioning.local_couchdb_uri, t, view, key


    # Action!
    @get '/subscriber/': -> # auth_table
      if @query.k is 'username,domain'
        # Parse @v -- what is the actual format?
        [username,domain] = @query.v.split ","
        pipe_req @, 'subscriber', make_id('endpoint',"#{username}@#{domain}")
        return

      throw 'not handled'

    @get '/location/': -> # usrloc_table

      if @query.k is 'username'
        pipe_loc_req @, 'usrloc', @query.v
        return

      if @query.k is 'username,domain'
        [username,domain] = @query.v.split ','
        pipe_loc_req @, 'usrloc', "#{username}@#{domain}"
        return

      if not @query.k?
        pipe_loc_list @, 'usrloc', 'location/all' # Can't use _all_docs
        return

      throw 'not handled'

    cdb = require 'cdb'
    loc_db = cdb.new config.opensips_proxy.usrloc_uri

    @post '/location': ->

      doc = unquote_params(@body.k,@body.v,'location')
      # Note: this allows for easy retrieval, but only one location can be stored.
      # Use "callid" as an extra key parameter otherwise.
      doc._id = "#{doc.username}@#{doc.domain}"

      if @body.query_type is 'insert' or @body.query_type is 'update'

        loc_db.head doc._id, (p) =>
          doc._rev = p._rev if p._rev?
          loc_db.put doc, (r) =>
            if r.error then return @send ""
            @send r._id
        return

      if @body.query_type is 'delete'

        loc_db.head doc._id, (p) =>
          if not p._rev? then return @send ""
          doc._rev = p._rev
          loc_db.del doc, (p) =>
            if p.error then return @send ""
            @send ""
        return

      throw "not handled #{util.inspect @}"

    @get '/avpops/': ->

      if @query.k is 'uuid,attribute'
        [uuid,attribute] = @query.v.split ','
        pipe_req @, 'avpops', make_id attribute, uuid
        return

      if @query.k is 'username,domain,attribute'
        [username,domain,attribute] = @query.v.split ','
        pipe_req @, 'avpops', make_id(attribute,"#{username}@#{domain}")
        return

      throw 'not handled'


    @get '/dr_gateways/': ->
      if not @query.k?
        pipe_list_key @, 'dr_gateways', 'gateways_by_domain', config.sip_domain_name
        return
      ###
      my %attrs = ();
      $attrs{realm}    = $uac_realm if defined($uac_realm) && $uac_realm ne '';
      $attrs{user}     = $uac_user  if defined($uac_user ) && $uac_user  ne '';
      $attrs{pass}     = $uac_pass  if defined($uac_pass ) && $uac_pass  ne '';
      $attrs{force_mp} = $force_mp  if defined($force_mp ) && $force_mp  ne '';

      my $attrs = join(';', map { "$_=$attrs{$_}" } keys(%attrs) );
      ###

      throw 'not handled'

    @get '/dr_rules/': -> # ?c=ruleid,groupid,prefix,timerec,priority,routeid,gwlist,attrs
      if not @query.k?
        pipe_list_key @, 'dr_rules', 'rules_by_host', config.host
        return

      throw 'not handled'

    @get '/dr_groups/': ->

      if @query.k is 'username,domain'
        [username,domain] = @query.v.split ','
        # However we do not currently support "number@domain", so skip that.
        # (Compare to use_domain=0.)
        pipe_req @, 'dr_groups', make_id('number',username)
        return

      throw 'not handled'

    @get '/dr_gw_lists/': -> # id,gwlist
      if not @query.k?
        pipe_list_key @, 'dr_gw_lists', 'gwlists_by_host', config.host
        return

      throw 'not handled'

    @get '/version/': ->
      if @query.k is 'table_name' and @query.c is 'table_version'

        # Versions for OpenSIPS 1.7.0
        versions =
          location: 1006
          subscriber: 7
          dr_gateways: 4
          dr_rules: 3

        return "int\n#{versions[@query.v]}\n"

      throw 'not handled'
