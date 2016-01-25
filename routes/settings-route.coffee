express = require('express')
router = express.Router()
async = require 'async'
eventManager = require '../data/event-manager'
taskManager = require '../data/task-manager'
{ types, User, Calendar, EventMetadata, EventPartial, TextSearch, TaskList, Task } = require '../data/database-mongoose'
googleHook = require('../data/google-calendar')

# Normal settings page
router.get '/', (req, res) ->
  email = req.session.email
  if email?
    # Get token for email
    User.getUser email, (error, user) ->
      if error?
        res.redirect '/?error=' + error.message

      else
        # Get auth for querying calendars
        auth = googleHook.getAuth user.tokens.access_token
        
        # Get calendar list
        listOptions = {
          auth,
          minAccessRole: "reader",
          fields: "items(accessRole,backgroundColor,description,foregroundColor,id,location,summary,timeZone)"
        }
        googleHook.getCalendar().calendarList.list listOptions, (error, calendarList) ->
          if error?
            res.redirect '/?error=' + error.message
          else
            Calendar.find({ owner: user.email })
            .exec (error, mcalendars)->
              if error?
                res.redirect '/?error=' + error.message
              else
                calendarIds = {}
                for c in mcalendars
                  calendarIds[c.calendarId] = c
                for item in calendarList.items
                  c = calendarIds[item.id]
                  item.checked = c?
                  if c?
                    item.suspended = c.suspended
                    item.mdescription = c.description
                    item.mname = c.name
                    item.mtype = c.type
                    item.mindexinfo = c.indexInfo
                    if c.lastIndex?.toLocaleString?
                      item.mlastindex = c.lastIndex.toLocaleString().replace(/(:\d\d)[^:]+$/, "$1")
                    else
                      item.mlastindex = "Unknown"

                acted = null

                render = (error) ->
                  if error?
                    res.render "error", { error }

                  else
                    if acted
                      res.redirect "/settings"
                    else
                      calendars = calendarList.items.sort (a, b) ->
                        if a.checked isnt b.checked
                          return if a.checked then -1 else 1
                        else if a.suspended isnt b.suspended
                          return if a.suspended then 1 else -1
                        else
                          return if a.summary.localeCompare(b.summary)

                      # Get tasks list
                      tasksListOptions = {
                        auth,
                        minAccessRole: "reader",
                        fields: "items(id,title)"
                      }
                      googleHook.getTasks().tasklists.list tasksListOptions, (error, taskLists) ->
                        if error?
                          render error

                        else
                          TaskList.getTaskLists user.email, (error, tasklists) ->
                            checkedtasklists = {}
                            checkedtasklists[tlId] = true for { tlId } in tasklists
                            inactivetasklists = []
                            # weed out not initiallized tasklists
                            for taskListItem in taskLists.items
                              unless checkedtasklists[taskListItem.id]?
                                inactivetasklists.push {
                                  id: taskListItem.id
                                  title: taskListItem.title
                                }

                            for tl in tasklists
                              tl.mlastindex ?= "Never"

                            locals = {
                              title: "Organization Settings",
                              deposit: user.deposit,
                              types,
                              calendars,
                              tasklists,
                              inactivetasklists
                            }

                            res.render "organization-settings-page", locals

                a = req.query.a
                cId = req.query.cId
                if a and calendarIds[cId]?
                  acted = { a, targetCalendar: calendarIds[cId].name }

                  switch a

                    when "unsuspend"
                      Calendar.getCalendar cId, (error, cal) ->
                        if error? then render error else
                        if cal?
                          cal.suspended = false

                          eventManager.reindexEvents [cId], (error) ->
                            if error? then render error else
                              cal.save render
                        else
                          render "Calendar-doesnt-exist!"

                    when "suspend"
                      Calendar.getCalendar cId, (error, cal) ->
                        if error?
                          render error
                        else if cal?
                          cal.suspended = true
                          cal.save (error) ->
                            if error?
                              render error
                            else
                              async.parallel [
                                ((cb)-> EventPartial.remove({c:cal}, cb))
                                ((cb)-> TextSearch.remove({c:cal}, cb)) 
                              ], render
                        else
                          render "Calendar-doesnt-exist!"

                    when "delete"
                      user.calendars = user.calendars.filter ((e)->e.calendarId isnt cId)
                      user.save (error)->
                        if error? then render error else

                          Calendar.getCalendar cId, (error, cal) ->
                            if error? then render error else

                            if cal?
                              async.parallel [
                                ((cb)-> EventPartial.remove({c:cal}, cb))
                                ((cb)-> TextSearch.remove({c:cal}, cb))
                                ((cb)-> EventMetadata.remove({cId}, cb))
                                ((cb)-> Calendar.remove({calendarId: cId}, cb))
                              ], render
                            else
                              render "Calendar-doesnt-exist!"

                    when "reindex"
                      eventManager.indexEvents auth, cId, render


                    else
                      render()

                else if a is "activate"
                  # Add calendar to user's calendars
                  user.calendars.push cId
                  user.save (error, user) ->
                    if error?
                      render error
                    else
                      getOptions = {
                        auth,
                        calendarId: cId,
                        fields: "backgroundColor,description,summary"
                      }

                      googleHook.getCalendar().calendarList.get getOptions, (error, gcalendar) ->
                        if error? then render error
                        else
                          acted = { a, targetCalendar: null }
                          
                          (new Calendar {
                            calendarId: cId,
                            owner: email,
                            name: gcalendar.summary,
                            slug: gcalendar.summary.toLowerCase().replace(/[^a-z0-9]+/g, "-"),
                            type: "I",
                            description: gcalendar.description or "",
                            color: gcalendar.backgroundColor,
                            suspended: false
                          }).save (error, cal)->
                            if error?
                              render error

                            else
                              (new TextSearch {
                                c: cal,
                                t: cal.type,
                                s: [
                                  cal.name,
                                  cal.description or ""
                                ]
                              }).save render
                # Deposits
                else if a is "set-deposit"
                  taskManager.removeDeposit user.deposit, (error) ->
                    if error?
                      render error

                    else
                      user.deposit = cId
                      user.save render
                  

                else if a is "unset-deposit"
                  taskManager.removeDeposit user.deposit, (error) ->
                    if error?
                      render error

                    else
                      user.deposit = null
                      user.save render

                else if a is "tasklist-delete"
                  taskManager.delete(auth, user, req.query.tlId, render)

                else if a is "tasklist-activate"
                  taskManager.activate(auth, user, req.query.tlId, render)

                else if a is "tasklist-deposit"
                  taskManager.deposit(auth, user, req.query.tlId, render)

                else
                  render()
                ###
                else if a is "reload-tasklists"
                  # Get tasks list
                  tasksListOptions = {
                    auth,
                    minAccessRole: "reader",
                    fields: "items(id,title)"
                  }
                  googleHook.getTasks().tasklists.list tasksListOptions, (error, taskLists) ->
                    if error?
                      render error

                    else
                      user.tasklists = taskLists.items
                      user.save render ###
  else
    res.redirect '/'

router.post '/:calendarId', (req, res) ->
  email = req.session.email
  calendarId = decodeURIComponent(req.params.calendarId)
  if email?
    # Get token for email
    User.getUser email, (error, user) ->
      if error?
        res.redirect '/?error=' + error.message
      else if !(~user.calendars.indexOf(calendarId))
        res.redirect '/?error=' + encodeURIComponent("Insufficient permissions")
      else
        # This is used so we can redirect when body elements aren't present which throw errors
        redirecterr = (error) ->
          urlPath = '/settings/' # + encodeURIComponent(calendarId)
          if error
            res.render "error", { error }
          else
            res.redirect urlPath + '?saved'

        saveCalendar = (error, calendar) ->
          if error?
            res.redirect '/?error=' + error.message
          else
            try
              calendar.name = req.body.name
              calendar.description = req.body.description
              calendar.slug = req.body.name.toLowerCase().replace(/[^a-z0-9]+/g, '-')

              # Called after calendar is saved
              updateTextSearch = (error) ->
                if error?
                  redirecterr error

                else
                  # Update or create TextSearch
                  TextSearch.findOne {c: calendar}, (error, tSearch) ->
                    if error?
                      callback error

                    else
                      if not tSearch?
                        tSearch = new TextSearch({c: calendar})
                      tSearch.t = calendar.type
                      tSearch.s = [
                        calendar.name,
                        calendar.description
                      ]

                      tSearch.save redirecterr
              
              newType = if types[req.body.type]? then req.body.type else "I"
              typechanged = newType isnt calendar.type
              calendar.type = newType

              if typechanged
                async.parallel [
                  ((cb) ->
                    EventPartial
                    .find { c: calendar }
                    .setOptions { multi: true }
                    .update { $set: { t: newType } }, cb
                  ),
                  ((cb) ->
                    TextSearch
                    .find { c: calendar }
                    .setOptions { multi: true }
                    .update { $set: { t: newType } }, cb
                  ),
                  ((cb) ->
                    EventMetadata
                    .find { cal: calendar }
                    .setOptions { multi: true }
                    .update { $set: { t: newType } }, cb
                  ),
                  ((cb) ->
                    calendar.save(cb)
                  )
                ], updateTextSearch

              else
                calendar.save updateTextSearch
              
            catch error
              redirecterr error
        
        Calendar.getCalendar calendarId, (error, calendar) ->
          if error?
            saveCalendar error
          
          else if calendar?
            # Calendar exists
            saveCalendar null, calendar

          else
            # Calendar not initiallized properly
            res.redirect('/settings')
  else
    res.redirect '/auth/login'

# Normal organization settings page
router.get '/:calendarId', (req, res) ->
  email = req.session.email
  calendarId = decodeURIComponent(req.params.calendarId)
  if email?
    # Get token for email
    User.getUser email, (error, user) ->
      if error?
        res.redirect '/?error=' + error.message
      else if !(~user.calendars.indexOf(calendarId))
        res.redirect '/?error=' + encodeURIComponent("Insufficient permissions")
      else
        renderCalendarSettings = (error, calendar, isNew) ->
          if error?
            res.redirect '/?error=' + error.message
          else
            locals = {
              title: "Calendar Settings",
              types,
              isNew,
              calendarName: calendar.name,
              calendarSlug: calendar.slug,
              selectedType: calendar.type,
              calendarColor: calendar.color,
              calendarDescription: calendar.description
            }

            res.render "organization-settings-calendar-page", locals
        Calendar.getCalendar calendarId, (error, calendar) ->
          if error?
            renderCalendarSettings error
          else
            if calendar?
              isNew = false
              renderCalendarSettings null, calendar, isNew

            else
              # Calendar not initiallized properly
              renderCalendarSettings new Error "Calendar not initiallized!"

  else
    res.redirect '/'

module.exports = router