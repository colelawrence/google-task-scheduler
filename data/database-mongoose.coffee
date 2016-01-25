
mongoose = require 'mongoose'

mongoose.connect('mongodb://localhost/task-scheduler')
db = mongoose.connection
`
db.on('error', console.error.bind(console, 'connection error:'));
db.once('open', function callback () {
  console.log("Mongoose Connected")
});
`

exports.User = require './models/user-model.coffee'
exports.Calendar = require './models/calendar-model.coffee'
exports.TextSearch = require './models/text-search-model.coffee'
exports.EventPartial = require './models/event-partial-model.coffee'
exports.EventMetadata = require './models/event-metadata-model.coffee'
exports.TaskList = require './models/tasklist-model.coffee'
exports.Task = require './models/task-model.coffee'
exports.PlannedTask = require './models/planned-task-model.coffee'

exports.types = {
  "C": "Campus Organization",
  "I": "Interest Group",
  "F": "Fraternity",
  "S": "Sorority",
  "R": "Religion",
  "A": "Academic",
  "P": "Sport",
  "O": "Other"
}

exports.mongoose = mongoose