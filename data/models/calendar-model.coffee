
mongoose = require 'mongoose'

# Calendar Schema
calendarSchema = mongoose.Schema {
  owner:      String, # Email
  calendarId: String,
  type:   String, # [F]raternity, [S]orority, S[P]ort, [I]nterest Group, [C]ampus Organization, [R]eligion
  name:   String,
  slug:   { type: String, lowercase: true, trim: true },
  description: String,
  color:    String,
  lastIndex: Date,    # Last index date
  indexInfo: String,  # index counts, readable string
  nextSyncToken: String,
  suspended: Boolean
}

# calendarSchema.index { name: 'text', description: 'text', owner: 'text' }

statics = {
  getCalendar: (calendarId, callback) ->
    this.findOne({ calendarId })
    .exec callback
  getIndexedCalendars: (callback) ->
    this.find({ suspended: false }, 'calendarId')
    .exec (error, calColl) ->
      if error?
        callback error

      else
        callback null, calColl.map((E)->E.calendarId)
}

methods = {
}

for name, staticfn of statics
  calendarSchema.statics[name] = staticfn
for name, methodfn of methods
  calendarSchema.methods[name] = methodfn

module.exports = mongoose.model 'Calendar', calendarSchema