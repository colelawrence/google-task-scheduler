express = require('express');
router = express.Router();
async = require 'async'
{ User, Calendar, TaskList, Task } = require '../data/database-mongoose'
googleHook = require('../data/google-calendar')

getAllTasks = require '../data/get-all-tasks.coffee'
getAllEvents = require '../data/get-all-events.coffee'

# /plan
router.get '/', (req, res, next) ->
  res.render 'plan', {
    title: 'Task Planner'
  }

router.get '/json', (req, res, next) ->
  getAllTasks req.user, req.auth, (error, allTasks) ->
    if error? then next error else
      getAllEvents req.user, req.auth, (error, allEvents, allEventMetadatas) ->
        if error? then next error else
          res.json {
            tasks: allTasks
            events: allEvents
            eventMetadatas: allEventMetadatas
            script: req.user.scheduling_script
          }


module.exports = router
