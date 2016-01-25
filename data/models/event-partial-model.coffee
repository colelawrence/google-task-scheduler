mongoose = require 'mongoose'

moment = require 'moment'

# Event Partial Schema
eventPartialSchema = mongoose.Schema {
  e: { type: mongoose.Schema.Types.ObjectId, ref: 'EventMetadata' },
  c: { type: mongoose.Schema.Types.ObjectId, ref: 'Calendar' },
  s: Number  # Start
}

statics = {
}

methods = {
}

for name, staticfn of statics
  eventPartialSchema.statics[name] = staticfn
for name, methodfn of methods
  eventPartialSchema.methods[name] = methodfn

module.exports = mongoose.model 'EventPartial', eventPartialSchema