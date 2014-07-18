'use strict';
var fs = require('fs'),
    moment = require('../../bower_components/momentjs/moment.js'),
    csv = require('csv-parse'),
    pathDatasets = __dirname + '/../../app/data/';
var datasets = fs.readdirSync(pathDatasets),
    calendars = [];
/**
 * collect datasets
 */
if (datasets.length > 0) {
    datasets.forEach(function(d, i) {
        // calendars
        if (/^calendar.*\.csv/gi.test(d)) {
            calendars.push(pathDatasets + d);
        }
    });
}
/**
 * merge calendars
 */
var dataCalendar = [];
calendars.sort(function(a, b) {
    var dateA = new Date(a.replace(/.*(\d{2}\-\d{2}\-\d{4}).*/, '$1'));
    var dateB = new Date(b.replace(/.*(\d{2}\-\d{2}\-\d{4}).*/, '$1'));
    if (dateA > dateB) {
        return 1;
    } else if (dateA < dateB) {
        return -1;
    }
    return 0;
});
calendars.forEach(function(calendar) {
    var year = calendar.replace(/.*\b(\d{4})\b.*/g, '$1');
    fs.readFile(calendar, function(err, data) {
        csv(data, {
            columns: true
        }, function(err, out) {
            if (out) {
                out.forEach(function(row) {
                    var o = {};
                    for (var p in row) {
                        var pp = p.toLowerCase();
                        if (/description/i.test(p)) {
                            p = 'event';
                        }
                        o[pp] = row[p];
                    }
                    var realDate = moment([o.date, year, o.time, o['time zone']].join(' ')).toDate();
                });
            }
        });
    });
});