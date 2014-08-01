'use strict';
var fs = require('fs'),
    natural = require('natural'),
    string = require('../lib/string'),
    moment = require('../../bower_components/momentjs/moment.js'),
    jsonpath = require('../../bower_components/jsonpath/lib/jsonpath.js'),
    csv = require('csv-parse'),
    q = require('q'),
    opts = require('optimist').usage('Dataset merge utility. Options cannot be combined.\nUsage: $0').alias('c', 'calendar').describe('c', 'Merge historical calendars in one dataset').alias('e', 'events-crosses').describe('e', 'Merge calendar events with currency crosses').alias('d', 'debug').describe('d', 'Show debug info only'),
    pathDatasets = __dirname + '/../../app/data/',
    csvCalendarOut = pathDatasets + 'calendar.csv',
    csvMultisetsInput = pathDatasets + 'multisetsInputs.csv',
    csvEventsCrossesOut = pathDatasets + 'eventsCrossesInputs.csv';
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
var dataCalendars = [];
var mergeCalendars = function() {
    var def = q.defer();
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
        var data = fs.readFileSync(calendar, 'utf-8');
        var parser = csv({
            columns: true,
            trim: true,
            quote: '',
            auto_parse: false,
            skip_empty_lines: true
        });
        parser.on('readable', function() {
            var row = null;
            try {
                while (row = parser.read()) {
                    // normalize fields
                    var o = {}, lastP = null,
                        keys = Object.keys(row),
                        ix = keys.indexOf('undefined');
                    if (ix !== -1) {
                        row[keys[ix - 1]] = row[keys[ix - 1]] + '.' + row[keys[ix]];
                        delete row[keys[ix]];
                    }
                    if (Object.keys(row).length > 9) {
                        continue;
                    }
                    for (var p in row) {
                        try {
                            var pp = p.toLowerCase();
                            if (/description/i.test(p)) {
                                pp = 'event';
                            } else if (/actual|forecast|previous/gi.test(p)) {
                                // normalize numbers
                                row[p] = row[p] ? parseFloat(row[p].replace(/[^\d\.\,\-\+]+/g, '').replace(/\,/g, '.')) : null;
                            }
                            var curr = row.Currency || row.currency;
                            o[pp] = /event/i.test(pp) ? string.normalizeEventName(row[p], curr.toUpperCase()) : row[p];
                        } catch (err) {
                            console.log('a: ' + err);
                        }
                    }
                    try {
                        var date = moment([o.date, year, o.time, o['time zone']].join(' '));
                        o.currency = o.currency.toUpperCase();
                        o.timestamp = date.valueOf();
                        o.date = moment(o.timestamp).format('YYYY-MM-DD');
                        o.event = o.event ? o.event : null;
                    } catch (err) {
                        console.log('b: ' + err);
                    }
                    delete o.time;
                    delete o['time zone'];
                    if (!o.actual ||  o.actual === '' || /\d{4}\_(?:\d{2}\_){2}/gi.test(o.event)) {
                        continue;
                    } else if (!(/low|medium|high/gi.test(o.importance)) || !(/[\d\.\-\+]+/g.test(o.actual))) {
                        continue;
                    } else {
                        dataCalendars.push(o);
                        dataEvents.push(o.currency + '|' + o.event);
                    }
                }
            } catch (err) {
                console.log('c: ' + err);
            }
        });
        parser.on('error', function(err) {
            console.log(calendar);
            console.log(err.message);
        });
        parser.on('finish', function() {
            def.resolve();
        });
        parser.write(data);
        parser.end();
    });
    return def.promise;
};
// merge events / currencies
var dataCurrencies = [];
var getCurrenciesValues = function() {
    var _def = q.defer();
    var data = fs.readFileSync(csvMultisetsInput, 'utf-8');
    var parser = csv({
        columns: true,
        trim: true,
        auto_parse: true,
        skip_empty_lines: true
    });
    parser.on('readable', function() {
        var row = null;
        while (row = parser.read()) {
            // normalize fields
            var o = {};
            for (var p in row) {
                var pp = p.toLowerCase().replace(/\s+\-\s+[a-z]+/gi, '');
                if (/^quandl\./gi.test(pp)) {
                    pp = pp.replace(/^quandl\.([a-z]+).*$/gi, '$1');
                }
                if (!(/date/gi.test(pp))) {
                    o[pp] = row[p] ||  null;
                } else {
                    o[pp] = row[p].trim();
                }
            }
            dataCurrencies.push(o);
        }
    });
    parser.on('error', function(err) {
        console.log(err.message);
        _def.reject(err);
    });
    parser.on('finish', function() {
        _def.resolve(dataCurrencies);
    });
    parser.write(data);
    parser.end();
    return _def.promise;
};
var dataFullCalendar = [],
    dataEvents = [];
var getCalendarsValues = function() {
    var _def = q.defer();
    var data = fs.readFileSync(csvCalendarOut, 'utf-8');
    var parser = csv({
        columns: true,
        trim: true,
        auto_parse: true,
        skip_empty_lines: true,
        quote: ''
    });
    parser.on('readable', function() {
        var row = null;
        while (row = parser.read()) {
            dataEvents.push(row.currency + '|' + row.event);
            dataFullCalendar.push(row);
        }
    });
    parser.on('error', function(err) {
        console.log(err.message);
    });
    parser.on('finish', function() {
        dataEvents = dataEvents.filter(Boolean).filter(function(ev, ix, arr) {
            return arr.indexOf(ev) == ix;
        });
        dataEvents.sort();
        _def.resolve(dataFullCalendar);
    });
    parser.write(data);
    parser.end();
    return _def.promise;
};
var dataEventsCurrencies = [],
    mapDateCross = {}, mapDateEvent = {};
var mergeEventsCurrencies = function() {
    var def = q.defer();
    getCurrenciesValues().then(function(crosses) {
        if (crosses.length > 0) {
            // for faster access, create a map indexed by date
            crosses.forEach(function(cross) {
                var date = cross.date;
                delete cross.date;
                mapDateCross[date] = cross;
            });
            getCalendarsValues().then(function(calendars) {
                console.log(dataEvents.length + ' events loaded');
                // create csv
                var cols = dataEvents.concat(Object.keys(crosses[0]));
                fs.appendFileSync(csvEventsCrossesOut, cols.join(',') + '\n');
                // map events/date
                calendars.forEach(function(cal) {
                    var date = cal.date;
                    if (!mapDateEvent[date]) {
                        mapDateEvent[date] = {};
                    }
                    var prop = cal.currency + '|' + cal.event;
                    if (!mapDateEvent[date][prop]) {
                        mapDateEvent[date][prop] = cal.actual ||  null;
                    }
                });
                // generate row
                for (var d in mapDateEvent) {
                    var cross = mapDateCross[d] || null;
                    var row = {};
                    cols.forEach(function(col) {
                        row[col] = null;
                    });
                    if (cross !== null) {
                        for (var c in cross) {
                            row[c] = cross[c];
                        }
                        for (var ev in mapDateEvent[d]) {
                            row[ev] = mapDateEvent[d][ev];
                        }
                    }
                    // write to csv
                    var data = [];
                    for (var p in row) {
                        data.push(row[p]);
                    }
                    fs.appendFileSync(csvEventsCrossesOut, data.join(',') + '\n');
                }
                def.resolve();
            });
        } else {
            def.reject();
        }
    });
    return def.promise;
};
if (opts.argv.calendar) {
    // generate historical calendar
    mergeCalendars().then(function() {
        var cols = Object.keys(dataCalendars[0]);
        dataEvents = dataEvents.filter(Boolean).filter(function(ev, ix, arr) {
            return arr.indexOf(ev) == ix;
        });
        dataEvents.sort();
        // calculate distance for each event name
        if (opts.argv.debug) {
            dataEvents.forEach(function(evName) {
                for (var ev in dataEvents) {
                    var a = evName.split('|')[1],
                        b = dataEvents[ev].split('|')[1];
                    if (evName === dataEvents[ev] || evName.split('|')[0] !== dataEvents[ev].split('|')[0]) {
                        continue;
                    } else {
                        var dist = natural.JaroWinklerDistance(a.replace(/_/g, ' '), b.replace(/_/g, ' '));
                        if (dist >= 0.88 && dist < 1) {
                            console.log(evName + ' - ' + dataEvents[ev]);
                        }
                    }
                }
            });
        } else {
            fs.appendFileSync(csvCalendarOut, cols.join(',') + '\n');
            dataCalendars.forEach(function(row) {
                var data = [];
                for (var c in row) {
                    data.push(row[c]);
                }
                fs.appendFileSync(csvCalendarOut, data.join(',') + '\n');
            });
        }
    });
} else if (opts.argv.e) {
    if (!fs.existsSync(csvCalendarOut)) {
        console.log('You should merge the calendars first (option -c).\n');
        opts.showHelp();
        process.exit(1);
    } else {
        mergeEventsCurrencies().then(function() {
            console.log('Done');
        }, function(err) {
            console.log(err);
        });
    }
} else {
    opts.showHelp();
}