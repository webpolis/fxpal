'use strict';
var fs = require('fs'),
    moment = require('../../bower_components/momentjs/moment.js'),
    csv = require('csv-parse'),
    q = require('q'),
    opts = require('optimist').usage('Dataset merge utility. Options cannot be combined.\nUsage: $0').alias('c', 'calendar').describe('c', 'Merge historical calendars in one dataset').alias('e', 'events-crosses').describe('e', 'Merge calendar events with currency crosses'),
    pathDatasets = __dirname + '/../../app/data/',
    csvCalendarOut = pathDatasets + 'calendar.csv',
    csvMultisetsInput = pathDatasets + 'multisetsInputs.csv',
    csvEventsCurrenciesOut = pathDatasets + 'eventsCurrenciesOutputs.csv';
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
var normalizeEventName = function(event, currency) {
    var ret = event.trim();
    var reCurrency = new RegExp('[\\b\\s]*' + currency + '[\\b\\s]*(?!o)', 'gi');
    ret = ret.replace(/[\-\_\"\(\)\[\]]{1,}/g, ' ');
    ret = ret.replace(reCurrency, '');
    ret = ret.replace(/\'s?/gi, '');
    ret = ret.replace(/\s{1,}|millions?|mlns?/gi, ' ');
    ret = ret.replace(/\b(?:€|euros|euro|yen)\b/gi, '').replace(/€|¥/g, '');
    ret = ret.replace(/harmon?i[sz]ed/gi, 'Harmonized');
    ret = ret.replace(/\(([^\)]+)\/([^\)]*)\)/g, '($1o$2)');
    ret = ret.replace(/\(3m[^\)]*\)/gi, '(3M)');
    ret = ret.replace(/[\(\[]*(?:(?:australian dollar|[a-z]+\$|canadian dollar|new zealand dollar)?)?[\)\]]*/gi, '');
    ret = ret.replace(/\./g, '').replace(/\b([a-z]{1})[\b\s]+/gi, '$1').replace(/\//g, ' ').replace(/&/g, 'and');
    ret = ret.replace(/\bn?sa\b/gi, '');
    ret = ret.replace(/(price|sale|service|order)s?/gi, '$1');
    ret = ret.replace(/gross\s*domestic\s*products?(\s*)/gi, 'GDP$1');
    ret = ret.replace(/personal\s*consumption\s*expenditure(\s*)/gi, 'PCE$1');
    ret = ret.replace(/([a-z]{1})(?:roducer|onsumer)\s*price\s*index(\s*)/gi, '$1PI$2');
    ret = ret.replace(/under\s*employment(\s*)/gi, 'unemployment$1');
    ret = ret.replace(/perf\.?\s*of\.?\s*constr\.?(\s*)/gi, 'performance of construction$1')
    ret = ret.trim().replace(/[^\w\d]{1,}/g, '_');
    return ret.toUpperCase();
};
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
            while (row = parser.read()) {
                // normalize fields
                var o = {};
                for (var p in row) {
                    var pp = p.toLowerCase();
                    if (/description/i.test(p)) {
                        p = 'event';
                    }
                    o[pp] = /event/i.test(p) ? normalizeEventName(row[p], row.Currency.toUpperCase()) : row[p];
                }
                if (!o.actual ||  o.actual === '' ||  /\d{4}\_(?:\d{2}\_){2}/gi.test(o.event)) {
                    return;
                }
                var date = moment([o.date, year, o.time, o['time zone']].join(' '));
                o.currency = o.currency.toUpperCase();
                o.timestamp = date.valueOf();
                o.date = moment(o.timestamp).format('YYYY-MM-DD');
                o.event = o.event ? o.event : null;
                // normalize numbers
                o.actual = o.actual ? parseFloat(o.actual.replace(/[^\d\%\.\,\-]+/g, '')) : null;
                o.forecast = o.forecast ? parseFloat(o.forecast.replace(/[^\d\%\.\,\-]+/g, '')) : null;
                o.previous = o.previous ? parseFloat(o.previous.replace(/[^\d\%\.\,\-]+/g, '')) : null;
                delete o.time;
                delete o['time zone'];
                dataCalendars.push(o);
                dataEvents.push(o.currency + '|' + o.event);
            }
        });
        parser.on('error', function(err) {
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
var mergeEventsCurrencies = function() {
    var def = q.defer();
    getCurrenciesValues().then(function(currencies) {
        if (currencies.length > 0) {
            getCalendarsValues().then(function(calendars) {
                console.log(dataEvents);
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
        fs.appendFileSync(csvCalendarOut, cols.join(',') + '\n');
        dataCalendars.forEach(function(row) {
            var data = [];
            for (var c in row) {
                data.push(row[c]);
            }
            fs.appendFileSync(csvCalendarOut, data.join(',') + '\n');
        });
    });
} else if (opts.argv.e) {
    if (!fs.existsSync(csvCalendarOut)) {
        console.log('You should merge the calendars first (option -c).\n');
        opts.showHelp();
        process.exit(1);
    } else {
        mergeEventsCurrencies().then(function() {}, function(err) {
            console.log(err);
        });
    }
} else {
    opts.showHelp();
}