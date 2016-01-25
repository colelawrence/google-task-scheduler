mongoose = require 'mongoose'

# Planned Task Schema
taskSchema = mongoose.Schema {
  tlId: String,
  tId: String,
  cId: String,
  eventId: String,
}

statics = {
}

methods = {
}

for name, staticfn of statics
  taskSchema.statics[name] = staticfn
for name, methodfn of methods
  taskSchema.methods[name] = methodfn

module.exports = mongoose.model 'PlannedTask', taskSchema