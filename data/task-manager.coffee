
async = require 'async'
googleHook = require './google-calendar'
{ RRule } = require 'rrule'
{ Task, TaskList, PlannedTask, User } = require './database-mongoose'

ISO = (str) ->
  new Date(Date.parse(str))

updateTask = (evM, gevent, t, callback) ->
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

getAllTasks = (tasklistIds, auth, callback) ->
    

    async.doWhilst(
        processEvents           # do
        , (-> !!nextPageToken)  # while
        , (error) ->            # then
          if error
            callback error
          else
            callback null, tasks
      )

exports.depositTasks = (tasklistIds, callback) ->
  async.each(
    tasklistIds
    , (tasklistId, next) ->
      next()
    , callback
  )

unplan = (auth, cId, callback) ->
  (error, plannedTasks) ->
    unless error?
      async.each(
        plannedTasks
        , (planned, nextPlanned) ->
          # delete each planned event from their google calendar
          deleteOptions = {
            auth,
            calendarId: cId,
            eventId: planned.eventId,
          }
          googleHook.getCalendar().events.delete deleteOptions, (error) ->
            unless error?
              PlannedEvent.find(planned).remove().exec(nextPlanned)

            else
              next error

        , callback
      )
    else
      callback error

exports.removePlansByCalendar = (auth, cId, callback) ->
  PlannedTask.find({ cId })
  .exec unplan(auth, cId, callback)

exports.removePlansByTaskList = (auth, tlId, cId, callback) ->
  PlannedTask.find({ tlId, cId })
  .exec unplan(auth, cId, callback)

exports.activate = (auth, user, tlId, callback) ->
  TaskList.findOne({ tlId, userEmail: user.email })
  .exec (error, res) ->
    unless error
      unless res != null
        googleHook.getTasks().tasklists.get {
            auth,
            tasklist: tlId
          }, (error, task) ->
            unless error?
              # create TaskList db object
              (new TaskList {
                tlId: tlId
                userEmail: user.email,
                title: task.title
              }).save callback
            else callback error
      else callback()
    else callback error

exports.delete = (auth, user, tlId, callback) ->
  # remove deposit of tasklist
  exports.removePlansByTaskList auth, tlId, user.deposit, (error) ->
    unless error?
      # remove TaskList from DB
      TaskList.find({ tlId, userEmail: user.email}).remove().exec(callback)

    else callback error

exports.deposit = (auth, user, tlId, callback) ->
