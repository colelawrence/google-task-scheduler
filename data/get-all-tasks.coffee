async = require 'async'
{ User, Calendar, TaskList, Task } = require '../data/database-mongoose'
googleHook = require('../data/google-calendar')

# get all tasks appointed by one user
getAllTasks = (user, auth, callback) ->
  TaskList.getTaskLists user.email, (error, tasklists) ->
    if error? then next error else
      allTasks = []
      async.each tasklists
        , (tasklist, nextTasklist) ->
          nextPageToken = null

          retrieveTasks = (done) ->
            tasksListOptions = {
              auth: auth,
              tasklist: tasklist.tlId,
              fields: "items(due,id,notes,title),nextPageToken",
              showCompleted: false
            }

            if nextPageToken?
              tasksListOptions.pageToken = nextPageToken
            
            googleHook.getTasks().tasks.list tasksListOptions, (error, results) ->
                if error? then done(error) else
                  nextPageToken = results.nextPageToken

                  if results.items?.length
                    tasks = Array::slice.call results.items
                    allTasks = allTasks.concat(tasks
                      .filter((t) -> typeof t is "object")
                      .map (t) ->
                        t.tlId = tasklist.tlId
                        t.tasklist = tasklist.title
                        t
                    )
                  done()

          async.doWhilst(
            retrieveTasks           # do
            , (-> !!nextPageToken)  # while
            , nextTasklist          # then
          )
        , (error) ->
          callback(error, allTasks)

module.exports = getAllTasks