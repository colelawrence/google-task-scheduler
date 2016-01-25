
async = require 'async'
googleHook = require './google-calendar'
{ RRule } = require 'rrule'
{ Calendar, EventMetadata, EventPartial, TextSearch } = require './database-mongoose'
{ reindexRecurring } = require './event-index'

ISO = (str) ->
  new Date(Date.parse(str))

updateEvent = (evM, gevent, t, callback) ->
  # Make changes if changed
  evM.s = ISO(gevent.start.dateTime)  if gevent.start?.dateTime?
  evM.e = ISO(gevent.end.dateTime)    if gevent.end?.dateTime?

  evM.hL = gevent.htmlLink      if gevent.htmlLink?
  evM.iC = gevent.iCalUID       if gevent.iCalUID?
  
  evM.i.name = gevent.summary       if gevent.summary?
  evM.i.loc  = gevent.location      if gevent.location?
  evM.i.desc = gevent.description   if gevent.description?

  evM.t = t

  evM.r = gevent.recurrence[0].replace(/^RRULE:/, "")   if gevent.recurrence?.length
  evM.reId = gevent.recurringEventId                    if gevent.recurringEventId?

  evM.save (error) ->
    if error?
      callback error

    else
      # Update or create TextSearch
      TextSearch.findOne {e: evM}, (error, tSearch) ->
        if error?
          callback error

        else
          if not tSearch?
            tSearch = new TextSearch({e: evM, t: evM.t, c: evM.cal})
          tSearch.s = [
            evM.i.name,
            evM.i.desc
          ]

          tSearch.save(callback)

exports.reindexEvents = (calendarIds, callback) ->
  reindexRecurring calendarIds, (error, indexObj) ->
    callback error, indexObj

exports.indexEvents = (auth, calendarId, callback) ->
  Calendar.getCalendar calendarId, (error, calendar) ->
    if error?
      callback error
    
    else if not calendar?
      # Calendar not set-up
      callback null, false

    else
      gcalendar = googleHook.getCalendar()

      fields = "items(description,end,htmlLink,iCalUID,originalStartTime,id,recurrence,location,recurringEventId,start,status,summary,visibility),nextPageToken,nextSyncToken,updated"
      
      # This nextPageToken is set if there is another page
      nextPageToken = null

      nextSyncToken = calendar.nextSyncToken

      calendarType = calendar.type

      total = {
        updated: 0,
        created: 0,
        cancelled: 0,
        removed: 0
      }

      processEvents = (nextPage) ->
        listOptions = {
          calendarId,
          fields,
          auth,
          timeMin: "2016-01-20T10:00:00-06:00"
        }

        #if nextSyncToken?
        #  listOptions.syncToken = nextSyncToken

        if nextPageToken?
          listOptions.nextPageToken = nextPageToken
          nextPageToken = null

        gcalendar.events.list listOptions, (error, geventList) ->
          if error?
            nextPage error
          else
            
            async.each(
              geventList.items
              , (gevent, nextGevent) ->
                ### gevent
                {
                 "id": "5mg6i716i2o8s43k2pvgel2n2c_20140905T000000Z",
                 "status": "confirmed",
                 "htmlLink": "https://www.google.com/calendar/event?eid=NW1nNmk3MTZpMm84czQzazJwdmdlbDJuMmNfMjAxNDA5MDVUMDAwMDAwWiBtc2d6aHRAbQ",
                 "summary": "C Group - Chi Alpha",
                 "start": {
                  "dateTime": "2014-09-04T19:00:00-05:00"
                 },
                 "end": {
                  "dateTime": "2014-09-04T21:00:00-05:00"
                 },
                 "recurringEventId": "5mg6i716i2o8s43k2pvgel2n2c",
                 "iCalUID": "5mg6i716i2o8s43k2pvgel2n2c@google.com"
                },
                ###

                # Find in database
                eId = gevent.id

                EventMetadata.findOne { eId }
                .exec (error, evM) ->
                  if error?
                    console.log "nextGevent Error"
                    nextGevent error

                  else
                    if gevent.status isnt "cancelled" and gevent.start.dateTime?
                      if not evM?
                        Calendar.findOne {calendarId}, (error, cal)->
                          if error?
                            nextGevent error

                          else if not cal?
                            nextGevent new Error "Calendar for gevent is not active!"

                          else
                            # Create New eventMetadata
                            evM = new EventMetadata {
                              cId:  calendarId,  # CalendarId
                              cal,  # Calendar Document
                              eId,  # EventId for syncing
                              i: { name: null, desc: null, loc: null }
                            }
                            total.created++

                            console.log gevent.summary, gevent.start

                            updateEvent evM, gevent, calendarType, nextGevent

                      else
                        total.updated++

                        updateEvent evM, gevent, calendarType, nextGevent

                    else
                      # gevent is cancelled
                      if evM?
                        total.removed++
                        evM.remove nextGevent

                      else

                        if not (gevent.originalStartTime?.dateTime? and gevent.recurringEventId?)
                          # I don't quite understand what the point of an event cancellation without these attributes would do...
                          return nextGevent()

                        else

                          # gevent is cancelled and not created yet
                          # Possibly an instance of recurring event instance cancellation

                          total.cancelled++

                          Calendar.findOne {calendarId}, (error, cal)->
                            if error?
                              nextGevent error

                            else if not cal?
                              nextGevent new Error "Calendar for gevent is not active!"

                            else
                              # Create New eventMetadata
                              evM = new EventMetadata {
                                cId:  calendarId,  # CalendarId
                                cal,  # Calendar document
                                eId,  # EventId for syncing
                                c: true, # Cancelling event 
                                reId: gevent.recurringEventId,
                                s:   gevent.originalStartTime.dateTime
                              }

                              evM.save nextGevent

              , (error) ->
                if error?
                  nextPage error
                else
                  if geventList.nextPageToken?
                    nextPageToken = geventList.nextPageToken

                  # the nextSyncToken is only returned on the last page of results
                  else if geventList.nextSyncToken?
                    calendar.nextSyncToken = geventList.nextSyncToken
                    calendar.lastIndex = new Date()
                    calendar.indexInfo = """
                    updated:    #{total.updated},
                    created:    #{total.created},
                    cancelled:  #{total.cancelled},
                    removed:    #{total.removed}
                    """
                    calendar.save nextPage

                  else
                    nextPage(new Error "Expected nextPageToken or nextSyncToken")
            ) # async end

      async.doWhilst(
        processEvents           # do
        , (-> !!nextPageToken)  # while
        , (error) ->            # then
          if error
            callback error
          else
            exports.reindexEvents [calendarId], (error) ->
              callback error, total
      )

