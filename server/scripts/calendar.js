'use strict';
var moment = require('../../bower_components/momentjs/moment.js'),
    sleep = require('sleep');
var urlDailyFx = 'http://www.dailyfx.com/files/Calendar-{{startWeekDate}}.csv';
var weeks = 157; // 3 years aprox
// gen urls
for (var w = 0; w < weeks; w++) {
    var startWeekDate = moment().subtract('week', w).startOf('week').format('MM-DD-YYYY'),
        url = urlDailyFx.replace(/\{\{startWeekDate\}\}/gi, startWeekDate);
    console.log(url);
}