{ User } = require '../data/database-mongoose'
googleHook = require('../data/google-calendar')

# Normal settings page
module.exports = (req, res, next) ->
  email = req.session.email
  if email?
    # Get token for email
    User.getUser email, (error, user) ->
      if error?
        res.redirect '/?error=' + error.message

      else
        # Get auth for querying calendars
        req.user = user
        req.auth = googleHook.getAuth user.tokens.access_token

        next()
  else
    req.session.redir = req.url
    res.redirect "/login"
