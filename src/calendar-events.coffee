moment = require 'moment'

class CalendarEvents
  constructor: (eventdata) ->
    @data = {
      events: {} # eId -> { name: String, loc: String, desc: String, duration: milliseconds }
      occurrences: [] # { s: milliseconds, e: eId }
    }

    for eId, obj of eventdata
      ###
      obj: {
        id: "56a83544d45c1340179080ff"
        meta: Object
          _id: "56a83544d45c1340179080ff"
          e: "2016-01-11T17:00:00.000Z"
          i: Object
            desc: "Razib Iqbal"
            loc: "Cheek 205"
            name: "CSC 450"
          s: "2016-01-11T16:10:00.000Z"
        r: Array[54]
      }
      ###
      evt = {
        name: obj.meta.i.name
        loc: obj.meta.i.loc
        desc: obj.meta.i.desc
      }
      try
        evt.duration = moment(obj.meta.e).diff(moment(obj.meta.s))

      catch error
        # don't do much

      @data.events[eId] = evt
      unorderedPartials = []
      for occur in obj.r
        unorderedPartials.push({ s: occur, e: eId })

      @data.occurrences = @data.occurrences.concat unorderedPartials.sort (a, b) -> a.s - b.s


module.exports = CalendarEvents
