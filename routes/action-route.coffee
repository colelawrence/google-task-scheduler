express = require('express')
router = express.Router()
googleHook = require('../data/google-calendar')
{ User } = require('../data/database-mongoose')

info = (res, msg, data) ->
    res.render 'info', {
      title: msg,
      data: data
    }
  
# Insert the specified calendar into the user's list of calendars 
router.post '/', (req, res) ->
  redir = req.query.redirect
  if redir?
    res.redirect redir

  else
    info res, "hello", {}

module.exports = router