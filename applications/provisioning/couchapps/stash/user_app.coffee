###
(c) 2010 Stephane Alnet
Released under the Affero GPL3 license or above
###

# This couchapp is automatically inserted in a user database
# by the track_users agent.

couchapp = require('couchapp')

ddoc =
  _id: '_design/app'
  views: {}
  lists: {}     # http://guide.couchdb.org/draft/transforming.html
  shows: {}     # http://guide.couchdb.org/draft/show.html
  filters: {}   # used by _changes
  rewrites: {}  # http://blog.couchone.com/post/443028592/whats-new-in-apache-couchdb-0-11-part-one-nice-urls

module.exports = ddoc

# http://wiki.apache.org/couchdb/Document_Update_Validation
ddoc.validate_doc_update = (newDoc, oldDoc) ->

  provisioning_types = ["number","endpoint","location","host","domain"]

  required = (field, message) ->
    if not newDoc[field]
      throw {forbidden : message || "Document must have a " + field}

  unchanged = (field) ->
    if oldDoc and toJSON(oldDoc[field]) is toJSON(newDoc[field])
      throw {forbidden : "Field can't be changed: " + field}

  # Handle delete documents.
  if newDoc._deleted is true

    if oldDoc.do_not_delete
      throw {forbidden: 'Document is tagged as do_not_delete.'}

    # No further processing is required on deleted documents.
    return

  # Validate the document's type
  required("type")
  unchanged("type")
  type = newDoc.type

  # This code only handles provisioning types.
  # if not type in provisioning_types
  if provisioning_types.indexOf(type) < 0
    return

  required("account")

  # Each document of type T should have a .T record.
  required(type)
  unchanged(type)

  required(newDoc[type])
  expected_id = type+':'+newDoc[type]
  if newDoc._id isnt expected_id
    throw {forbidden: 'Document ID must be '+expected_id}

