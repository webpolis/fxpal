'use strict';
var fs = require('fs'),
    http = require('http'),
    q = require('q'),
    restify = require('restify'),
    moment = require('../bower_components/momentjs/moment.js'),
    server = restify.createServer(),
    sh = require('execSync'),
    string = require('./lib/string');
/**
 * Checks whether a file has been modified until now
 *
 * @param  {[type]}  fileName [description]
 * @param  {[type]}  date [description]
 * @return {Boolean}          [description]
 */
var isOutdatedFile = function(fileName, sinceMinutes) {
    var ret = true,
        stat = null;
    if (!sinceMinutes) {
        return ret;
    }
    if (fs.existsSync(fileName)) {
        stat = fs.statSync(fileName);
        ret = moment().zone('0000').diff(moment(stat.mtime).zone('0000'), 'minutes') > sinceMinutes;
    }
    return ret;
};
var requestCalendarCsv = function(url, cross) {
    var _def = q.defer();
    http.get(url, function(_res) {
        var body = '';
        _res.on('data', function(chunk) {
            body += chunk;
        });
        _res.on('end', function() {
            var ret = body.split('\n');
            ret = ret.filter(Boolean).map(function(row, ix) {
                if (ix === 0) {
                    return row;
                }
                var name = row.replace(/^(?:[^\,]+\,){4}([^\,]+).*$/gi, '$1');
                var code = string.normalizeEventName(name, cross);
                row += ',' + code;
                return row;
            });
            _def.resolve(ret);
        });
    }).on('error', _def.reject);
    return _def.promise;
};
/**
 * Init API
 */
server.use(restify.bodyParser({
    mapParams: false
}));
server.use(restify.CORS());
server.use(restify.gzipResponse());
server.pre(restify.pre.sanitizePath());
/**
 * API methods
 */
server.get('/api/portfolio', function respond(req, res, next) {
    res.setHeader('content-type', 'text/csv');
    var outFile = __dirname + '/../app/data/portfolio.csv';
    // only generate file if it's older than 1 day
    if (isOutdatedFile(outFile, 60 * 24)) {
        sh.run(['Rscript', __dirname + '/scripts/portfolio.r'].join(' '));
    }
    fs.readFile(outFile, {}, function(err, data) {
        res.send(data);
    });
    next();
});
server.get('/api/candles/:cross/:type/:start/:granularity', function respond(req, res, next) {
    res.setHeader('content-type', 'text/csv');
    var cross = req.params.cross.replace(/([a-z]{3})([a-z]{3})/gi, '$1_$2').toUpperCase();
    var outFile = [__dirname + '/../app/data/', cross, '-', req.params.type, '-', req.params.granularity, '.csv'].join('');
    var sinceMinutes = null;
    switch (req.params.granularity.toUpperCase()) {
        case 'H1':
            sinceMinutes = 60;
            break;
        case 'D':
            sinceMinutes = 60 * 24;
            break;
        case 'W':
            sinceMinutes = 10080;
            break;
        case 'M':
            sinceMinutes = 43800;
            break;
        default:
            var m = req.params.granularity.replace(/\M(\d+)/gi, '$1') || null;
            if (m !== null) {
                sinceMinutes = m + 1;
            }
            break;
    }
    // only generate file if it's older than XX minutes
    if (isOutdatedFile(outFile, sinceMinutes)) {
        sh.run(['Rscript', __dirname + '/scripts/candlesticks.r', req.params.start, req.params.cross.toUpperCase(), req.params.granularity.toUpperCase(), req.params.type.toLowerCase()].join(' '));
    }
    fs.readFile(outFile, {}, function(err, data) {
        res.send(data);
    });
    next();
});
server.post('/api/stemmer/:cross', function respond(req, res, next) {
    var ret = [];
    res.setHeader('content-type', 'application/json');
    if (req.body.length > 0) {
        ret = req.body.map(function(txt) {
            return string.normalizeEventName(txt, req.params.cross.toUpperCase());
        });
        res.send(ret);
    } else {
        res.send(ret);
    }
    next();
});
server.post('/api/calendar/:cross', function respond(req, res, next) {
    var ret = [],
        all = [];
    res.setHeader('content-type', 'text/csv');
    if (req.body.length > 0) {
        all = req.body.map(function(url) {
            return requestCalendarCsv(url, req.params.cross.toUpperCase());
        });
        q.all(all).then(function(ret) {
            var cols = null,
                arrFinal = [];
            ret.forEach(function(arr) {
                if (cols === null) {
                    cols = arr[0] + ',Code';
                }
                arr = arr.splice(1);
                arrFinal = arrFinal.concat(arr);
            });
            arrFinal.unshift(cols);
            var out = arrFinal.join('\n').trim();
            res.send(out);
        });
    } else {
        res.send(ret);
    }
    next();
});
var resCalendarStrength = function respond(req, res, next) {
    res.setHeader('content-type', 'text/csv');
    var cross = req.params.cross && req.params.cross.match(/[a-z]{3}/gi) || [];
    var weeks = req.params.weeks ||  52;
    var outFile = [__dirname + '/../app/data/', 'calendar', '-', weeks];
    // only generate file if it's older than XX minutes
    if (isOutdatedFile(outFile, 5)) {
        var cmd = ['Rscript', __dirname + '/scripts/eventsStrength.r', req.params.weeks];
        if (cross.length > 0) {
            cmd = cmd.concat(cross);
            outFile = outFile.concat('-' + [cross[0], cross[1]].join('-'));
        }
        sh.run(cmd.join(' '));
    }
    outFile = outFile.concat(['-', 'strength', '.csv']);
    fs.readFile(outFile.join(''), {}, function(err, data) {
        res.send(data);
    });
    next();
};
server.get('/api/calendar/strength/:weeks/:cross', resCalendarStrength);
server.get('/api/calendar/strength/:weeks', resCalendarStrength);
server.get('/api/calendar/strength', resCalendarStrength);
/**
 * Init API server
 */
server.listen(9999, function() {
    console.log('%s listening at %s', server.name, server.url);
});