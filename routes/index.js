var express = require('express');
var router = express.Router();

/* GET home page. */
router.get('/', function(req, res, next) {
  res.render('index', {
    title: 'Task Scheduler',
    session: req.session,
    error: req.query.error
  });
});

module.exports = router;
