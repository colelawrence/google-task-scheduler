express = require('express');
router = express.Router();
async = require 'async'
{ User, Calendar, TaskList, Task } = require '../data/database-mongoose'
googleHook = require('../data/google-calendar')

getAllTasks = require '../data/get-all-tasks.coffee'
getAllEvents = require '../data/get-all-events.coffee'

# /plan
router.get '/', (req, res, next) ->
  getAllTasks req.user, req.auth, (error, allTasks) ->
    if error? then next error else
      getAllEvents req.user, req.auth, (error, allEvents) ->
        if error? then next error else
          res.render 'plan', {
            title: 'Task Scheduler',
            test1: allTasks
            test2: allEvents
            test3: req.user.scheduling_script
          }
            



module.exports = router