
mongoose = require 'mongoose'

# User Schema
userSchema = mongoose.Schema {
  email:    { type: String, lowercase: true, trim: true },
  name:     String,
  picture:  String,
  scheduling_script: String,
  deposit: String,
  tokens:     Object
}

statics = {
  # Used to get the user associated with account
  # callback(Error, User)
  getUser: (email, callback) ->
    email = email.toLowerCase()

    userQuery = this.findOne { 'email': email }

    userQuery.select('picture name email calendars deposit tasklists tokens scheduling_script')

    userQuery.exec callback

  getAllCalendars: (callback) ->
    this.find()
    .select('calendars')
    .exec (err, users) ->
      if err?
        callback err
      else
        cals = []
        # Collect all user calendars into the same array
        (cals.push(cal) for cal in user.calendars) for user of users 
        callback null, cals
}

methods = {
  addCalendar: (name, id, callback) ->
    for cal in this.calendars when cal.id is id
      return callback(new Error("Calendar with id: #{id}, already exists"))
    this.calendars.push { name, id }
    callback(null, this)

  removeCalendarById: (id, callback) ->
    this.calendars = [cal for cal in this.calendars when cal.id isnt id]
}

for name, staticfn of statics
  userSchema.statics[name] = staticfn
for name, methodfn of methods
  userSchema.methods[name] = methodfn

module.exports = mongoose.model 'User', userSchema