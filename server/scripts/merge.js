'use strict';
var fs = require('fs'),
    natural = require('natural'),
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
var normalizeEventName = function(event, currency) {
    var ret = event.trim(),
        months = [];
    for (var m = 0; m < 12; m++) {
        months.push(moment().month(m).format('MMM'));
    }
    var reCurrency = new RegExp('[\\b\\s]*' + currency + '[\\b\\s]*(?!o)', 'gi');
    var reMonths = new RegExp('[\\b\\s]+' + months.join('|') + '[\\b\\s]+', 'gi');
    ret = ret.replace(/[\-\_\"\(\)\[\]\%]{1,}/g, ' ');
    ret = ret.replace(reCurrency, '');
    ret = ret.replace(reMonths, '');
    ret = ret.replace(/\'s?/gi, '');
    ret = ret.replace(/\s{1,}|millions?|mlns?/gi, ' ');
    ret = ret.replace(/\b(?:€|euros|euro|yen)\b/gi, '').replace(/€|¥/g, '');
    ret = ret.replace(/harmon?i[sz]ed/gi, 'Harmonized');
    ret = ret.replace(/\(([^\)]+)\/([^\)]*)\)/g, '($1o$2)');
    ret = ret.replace(/\(3m[^\)]*\)/gi, '(3M)');
    ret = ret.replace(/[\(\[]*(?:(?:australian dollar|[a-z]+\$|canadian dollar|new zealand dollar)?)?[\)\]]*/gi, '');
    ret = ret.replace(/\./g, '').replace(/\b([a-z]{1})[\b\s]+/gi, '$1').replace(/\//g, ' ').replace(/&/g, 'and');
    ret = ret.replace(/^(.*)\s+[\w\d]{1}$/gi, '$1');
    ret = ret.replace(/\bn?sa\b|indicator|\bus\b/gi, '');
    ret = ret.replace(/(price|sale|service|order|loan|value|export|import|purchase|balance|condition)s?/gi, '$1');
    ret = ret.replace(/gross\s*domestic\s*products?(\s*)/gi, 'gdp$1');
    ret = ret.replace(/personal\s*consumption\s*expenditure(\s*)/gi, 'pce$1');
    ret = ret.replace(/([a-z]{1})(?:roducer|onsumer)\s*price\s*index(\s*)/gi, '$1pi$2');
    ret = ret.replace(/under\s*employment(\s*)/gi, 'unemployment$1');
    ret = ret.replace(/markit\s*.*/gi, 'markit pmi');
    ret = ret.replace(/manufacturing.*production/gi, 'manufacturing production');
    ret = ret.replace(/manufacutring/gi, 'manufacturing');
    ret = ret.replace(/^\bism\b.*/gi, 'ism');
    ret = ret.replace(/.*jobless.*claims.*/gi, 'jobless claims');
    ret = ret.replace(/.*continuing.*claims.*/gi, 'continuing claims');
    ret = ret.replace(/.*ban[dk].*of.*cand/gi, 'bank of canad');
    ret = ret.replace(/.*halifax.*house.*price.*/gi, 'halifax house price index');
    ret = ret.replace(/non\s+farm/gi, 'nonfarm');
    ret = ret.replace(/\bavg\b/gi, 'average');
    ret = ret.replace(/.*fed.*pace.*of.*(?:treasury|mbs).*/gi, 'fed pace purchase of treasury');
    ret = ret.replace(/perf\.?\s*of\.?\s*constr\.?(\s*)/gi, 'performance of construction$1');
    ret = ret.replace(/\b(?:mom|yoy|qoq|ytd|mth)\b/gi, '');
    ret = ret.replace(/\d+|[a-z]+\d+|\b[a-z]\b/gi, '');
    // stem
    natural.PorterStemmer.attach();
    ret = ret.tokenizeAndStem().join(' ');
    ret = ret.trim().replace(/[^\w\d]{1,}/g, '_').replace(/^(.*)_[\w\d]{1}$/gi, '$1');
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
                if (!o.actual ||  o.actual === '' ||  /\d{4}\_(?:\d{2}\_){2}/gi.test(o.event)) {
                    continue;
                } else {
                    dataCalendars.push(o);
                    dataEvents.push(o.currency + '|' + o.event);
                }
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