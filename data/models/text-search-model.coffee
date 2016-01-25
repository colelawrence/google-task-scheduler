mongoose = require 'mongoose'
textSearch = require('mongoose-text-search')

# Text Search Schema
textSearchSchema = mongoose.Schema {
  e: { type: mongoose.Schema.Types.ObjectId, ref: 'EventMetadata' }, # Optional
  c: { type: mongoose.Schema.Types.ObjectId, ref: 'Calendar' }, # Optional
  t: String # type
  s: [String], # Text to search [Name, Description]
}

statics = {
}

methods = {
}

for name, staticfn of statics
  textSearchSchema.statics[name] = staticfn
for name, methodfn of methods
  textSearchSchema.methods[name] = methodfn

textSearchSchema.plugin(textSearch)
textSearchSchema.index({ s: 'text' });

module.exports = mongoose.model 'TextSearch', textSearchSchema