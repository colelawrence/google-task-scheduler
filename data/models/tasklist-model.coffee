mongoose = require 'mongoose'

# Task List Schema
taskListSchema = mongoose.Schema {
  tlId: String,  # TaskListId
  userEmail: String,
  title: String,
  backgroundColor: String # unused
}

statics = {
  getTaskLists: (userEmail, callback) ->
    this.find({ userEmail })
    .exec callback
}

methods = {
}

for name, staticfn of statics
  taskListSchema.statics[name] = staticfn
for name, methodfn of methods
  taskListSchema.methods[name] = methodfn

module.exports = mongoose.model 'TaskList', taskListSchema