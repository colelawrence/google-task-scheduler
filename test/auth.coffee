google = require "../data/google-calendar"
g = require('googleapis')
{ Calendar } = require './database-mongoose'

data = require('./users.json')

msgzhttoken = data[0].tokens
colelawrtoken = data[1].tokens

msgzht = google.getAuth msgzhttoken
colelawr = google.getAuth colelawrtoken

eM = require "../data/event-manager"

AUTH = msgzht
CALENDARID = "msgzht@gmail.com"

indexEvents = ->
  eM.indexEvents AUTH, CALENDARID, (error, res) ->
    if res is false # calendar not setup
      console.log "calendar not set up"

indexEvents()