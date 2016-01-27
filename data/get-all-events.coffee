async = require 'async'
mongoose = require 'mongoose'
{ User, Calendar, EventPartial, EventMetadata } = require '../data/database-mongoose'
googleHook = require('../data/google-calendar')

# get all tasks appointed by one user
getAllEvents = (user, auth, callback) ->
  Calendar.getCalendars user.email, (error, calendars) ->
    if error? then next error else
      allEvents = {}
      async.each calendars
        , (calendar, nextCalendar) ->
          EventPartial.find({ c: calendar })
          .select("e s")
          .exec (error, evs) ->
              if error? then nextCalendar(error) else
                for evp in evs
                  idString = String(evp.e)
                  if not allEvents[idString]?
                    allEvents[idString] = {
                      id: evp.e
                      r: []
                    }
                  allEvents[idString].r.push(evp.s)
                nextCalendar()
        , (error) ->
          if error? then next error else
            # let's get those eventmetadatas!
            allEventsIds = Object.keys(allEvents).map( (id) -> mongoose.Types.ObjectId(id) )
            EventMetadata.find()
            .where("_id").in(allEventsIds)
            .select("s e o i.name i.desc i.loc id")
            .exec (error, ems) ->
              for ev in ems
                allEvents[ev.id].meta = ev
              callback(error, allEvents)

module.exports = getAllEvents
