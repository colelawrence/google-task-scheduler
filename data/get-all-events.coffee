async = require 'async'
{ User, Calendar, EventPartial } = require '../data/database-mongoose'
googleHook = require('../data/google-calendar')



# get all tasks appointed by one user
getAllEvents = (user, auth, callback) ->
  Calendar.getCalendars user.email, (error, calendars) ->
    if error? then next error else
      allEvents = []
      async.each calendars
        , (calendar, nextCalendar) ->
          EventPartial.find({ c: calendar }).exec (error, evs) ->
            if error? then nextCalendar(error) else
              allEvents = allEvents.concat evs
              nextCalendar()
        , (error) ->
          callback(error, allEvents)

module.exports = getAllEvents