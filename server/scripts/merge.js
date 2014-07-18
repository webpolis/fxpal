'use strict';
var fs = require('fs'),
    moment = require('../../bower_components/momentjs/moment.js'),
    csv = require('csv-parse'),
    q = require('q'),
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
var mergeCalendars = function() {
    var def = q.defer();
    calendars.forEach(function(calendar) {
        var year = calendar.replace(/.*\b(\d{4})\b.*/g, '$1');
        var data = fs.readFileSync(calendar);
        var parser = csv({
            columns: true,
            trim: true
        });
        parser.on('readable', function() {
            var row = null;
            while (row = parser.read()) {
                var o = {};
                for (var p in row) {
                    var pp = p.toLowerCase();
                    if (/description/i.test(p)) {
                        p = 'event';
                    }
                    o[pp] = row[p].trim();
                }
                if (!o.actual ||  o.actual === '') {
                    return;
                }
                var date = moment([o.date, year, o.time, o['time zone']].join(' '));
                o.currency = o.currency.toUpperCase();
                var re = new RegExp('^' + o.currency + '\\s+(.*)$', 'gi');
                o.event = o.event.replace(re, '$1');
                o.timestamp = date.valueOf();
                o.date = moment(o.timestamp).toDate();
                // normalize numbers
                o.actual = o.actual ? parseFloat(o.actual.replace(/[^\d\%\.\,\-]+/g, '')) : null;
                o.forecast = o.forecast ? parseFloat(o.forecast.replace(/[^\d\%\.\,\-]+/g, '')) : null;
                o.previous = o.previous ? parseFloat(o.previous.replace(/[^\d\%\.\,\-]+/g, '')) : null;
                delete o.time;
                delete o['time zone'];
                dataCalendar.push(o);
            }
        });
        parser.on('error', function(err) {
            //console.log(err.message);
        });
        parser.on('finish', function() {
            def.resolve();
        });
        parser.write(data);
        parser.end();
    });
    return def.promise;
};
mergeCalendars().then(function() {
    var cols = Object.keys(dataCalendar[0]),
        outCsv = __dirname + '/../../app/data/calendar.csv';
    fs.appendFileSync(outCsv, cols.join(',') + '\n');
    dataCalendar.forEach(function(row) {
        var data = [];
        for (var c in row) {
            data.push(row[c]);
        }
        fs.appendFileSync(outCsv, data.join(',') + '\n');
    });
});