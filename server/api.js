'use strict';
var fs = require('fs'),
    http = require('http'),
    q = require('q'),
    restify = require('restify'),
    moment = require('../bower_components/momentjs/moment.js'),
    server = restify.createServer(),
    sh = require('execSync'),
    string = require('./lib/string'),
    cron = require('cronzitto'),
    rio = require('rio');
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
        console.log('requesting calendar ' + url);
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
var runRScript = function(scriptName, opts) {
    var fname = [__dirname, '../server/scripts', [scriptName, 'r'].join('.')].join('/');
    var script = fs.readFileSync(fname, 'utf8').replace(/\n+|(?:\r\n)+/g, '');
    if (typeof(opts) !== 'undefined' && opts.entryPoint) {
        script = script + ';' + opts.entryPoint + '(' + JSON.stringify(opts.data) + ')';
    }
    rio.sourceAndEval(fname, opts); //rio.bufferAndEval(script.replace(/\;/g, '\n'));
    return true;
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
        if (runRScript('portfolio')) {
            fs.readFile(outFile, {}, function(err, data) {
                res.send(data);
            });
        }
    } else {
        fs.readFile(outFile, {}, function(err, data) {
            res.send(data);
        });
    }
    next();
});
server.get('/api/candles/:cross/:start/:granularity', function respond(req, res, next) {
    res.setHeader('content-type', 'text/csv');
    var cross = req.params.cross.replace(/([a-z]{3})([a-z]{3})/gi, '$1_$2').toUpperCase();
    var outFile = [__dirname + '/../app/data/candles/', cross, '-', req.params.granularity, '.csv'].join('');
    var bImgFile = [__dirname + '/../app/data/breakout/', cross, '-', req.params.granularity, '.jpg'].join('');
    var sinceMinutes = null;
    var instrument = /(?:[a-z]{3}){2}/gi.test(req.params.cross) ? req.params.cross.toUpperCase().replace(/([a-z]{3})([a-z]{3})/gi, '$1_$2') : req.params.cross.toUpperCase();
    switch (req.params.granularity.toUpperCase()) {
        case 'M15':
            sinceMinutes = 15;
            break;
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
        var rname = [__dirname, '../server/scripts', ['candlesticks', 'r'].join('.')].join('/');
        if (runRScript('candlesticks', {
            entryPoint: 'qfxAnalysis',
            data: {
                instrument: instrument,
                granularity: req.params.granularity.toUpperCase(),
                startDate: req.params.start
            }
        })) {
            // copy on deploy folder
            sh.run(['cp', outFile, outFile.replace(/\/app\//g, '/www/')].join(' '));
            sh.run(['cp', bImgFile, bImgFile.replace(/\/app\//g, '/www/')].join(' '));
            fs.readFile(outFile, {}, function(err, data) {
                res.send(data);
            });
        }
    } else {
        fs.readFile(outFile, {}, function(err, data) {
            res.send(data);
        });
    }
    next();
});
server.get('/api/candles/volatility', function respond(req, res, next) {
    res.setHeader('content-type', 'text/csv');
    var outFile = [__dirname + '/../app/data/', 'volatility', '.csv'].join('');
    var sinceMinutes = 60;
    // only generate file if it's older than XX minutes
    if (isOutdatedFile(outFile, sinceMinutes)) {
        if (runRScript('candlesticks', {
            entryPoint: 'qfxVolatility'
        })) {
            fs.readFile(outFile, {}, function(err, data) {
                res.send(data);
            });
        }
    } else {
        fs.readFile(outFile, {}, function(err, data) {
            res.send(data);
        });
    }
    next();
});
server.get('/api/currencyForce', function respond(req, res, next) {
    res.setHeader('content-type', 'text/csv');
    var outFile = [__dirname + '/../app/data/', 'force', '.csv'].join('');
    var sinceMinutes = 60;
    // only generate file if it's older than XX minutes
    if (isOutdatedFile(outFile, sinceMinutes)) {
        if (runRScript('candlesticks', {
            entryPoint: 'qfxForce'
        })) {
            fs.readFile(outFile, {}, function(err, data) {
                res.send(data);
            });
        }
    } else {
        fs.readFile(outFile, {}, function(err, data) {
            res.send(data);
        });
    }
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
    var sinceMinutes = 15;
    if (cross.length > 0) {
        outFile = outFile.concat('-' + [cross[0], cross[1]].join('-'));
    }
    outFile = outFile.concat(['-', 'strength', '.csv']).join('');
    // only generate file if it's older than XX minutes
    if (isOutdatedFile(outFile, sinceMinutes)) {
        if (runRScript('eventsStrength')) {
            fs.readFile(outFile, {}, function(err, data) {
                res.send(data);
            });
        }
    } else {
        fs.readFile(outFile, {}, function(err, data) {
            res.send(data);
        });
    }
    next();
};
server.get('/api/calendar/strength/:weeks/:cross', resCalendarStrength);
server.get('/api/calendar/strength/:weeks', resCalendarStrength);
server.get('/api/calendar/strength', resCalendarStrength);
server.listen(9999, function() {
    console.log('%s listening at %s', server.name, server.url);
});