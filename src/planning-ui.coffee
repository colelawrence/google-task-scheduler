window.$ = jQuery = require("jquery")
moment = require("moment")

CalendarEvents = require("./calendar-events.coffee")

toPlan = jQuery(".to-plan")
eventList = jQuery(".event-list")

console.log("planning")

testOutput = jQuery(".testOutput")

jQuery.getJSON "/plan/json", ( res ) ->
  events = new CalendarEvents(res.events)
  testOutput.text JSON.stringify(events.data, null, 2)
