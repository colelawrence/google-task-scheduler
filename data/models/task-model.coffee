mongoose = require 'mongoose'

# Event Metadata Schema
taskSchema = mongoose.Schema {
  tlId: String,  # TaskListId
  tL: { type: mongoose.Schema.Types.ObjectId, ref: 'TaskList' },
  tId: String,  # Task Id for syncing
  done: Boolean,
  due: Date,   # Due date
  title: String,
  desc: String,
}

statics = {
}

methods = {
}

for name, staticfn of statics
  taskSchema.statics[name] = staticfn
for name, methodfn of methods
  taskSchema.methods[name] = methodfn

module.exports = mongoose.model 'Task', taskSchema