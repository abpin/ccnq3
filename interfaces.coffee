#!/usr/bin/env coffee
# (c) 2012 Stephane Alnet

interfaces = require('os').networkInterfaces()

result = {}

for intf, r1 of interfaces
  do (intf,r1) ->
    for _ in r1
      do (_) ->
        # Skip internal addresses
        return if _.internal
        family = _.family.toLowerCase()
        address = _.address
        t = result[intf] ? {}

        # Another address for the same interface+family
        if t[family]?
          t.next ?= 0
          t.next++
          name = intf+'-'+t.next
          result[name] =
            address:address
        else
          t[family] = address
        result[intf] = t

console.log JSON.stringify result
