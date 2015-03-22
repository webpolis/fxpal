'use strict';
var fs = require('fs'),
    http = require('http'),
    https = require('https'),
    q = require('q'),
    restify = require('restify'),
    moment = require('../bower_components/momentjs/moment.js'),
    server = restify.createServer(),
    sh = require('exec-sync'),
    string = require('./lib/string'),
    cron = require('cronzitto'),
    rio = require('rio'),
    zlib = require('zlib'),
    csv = require('csv-parse'),
    sleep = require('sleep');
/**
 * Init server
 */
server.pre(restify.pre.sanitizePath());
/**
 * Global vars
 */
var crosses = null;
var periods = ['M15', 'H1', 'D', 'W', 'M'];
var reqCount = 0;
/**
 * Load oanda currencies
 */
var rs = fs.createReadStream(__dirname + '/../app/data/availableCrosses.csv');
var parser = csv({
    columns: true
}, function(err, data) {
    crosses = data;
});
rs.pipe(parser);
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
var requestOandaCandles = function(instrument, granularity, startDate, count, pause) {
    var _def = q.defer();
    var inFile = [__dirname + '/../.tmp/', instrument, '-', granularity];
    inFile = typeof(count) !== 'undefined' ? inFile.concat(['-', count, '.json']).join('') : inFile.concat('.json').join('');
    var oandaApiHost = 'api-fxpractice.oanda.com';
    var oandaToken = 'ce6b72e81af59be0bbc90152cad8d731-03d41860ed7849e3c4555670858df786';
    var urlParams = ['instrument=' + instrument, 'granularity=' + granularity, 'weeklyAlignment=Monday', 'candleFormat=bidask'];
    if (typeof(startDate) !== 'undefined') {
        urlParams.push('start=' + startDate);
    } else if (typeof(count) !== 'undefined') {
        urlParams.push('count=' + count);
    }
    var url = ['/v1/candles', urlParams.join('&')].join('?');
    var opts = {
        host: oandaApiHost,
        path: url,
        headers: {
            'Authorization': ['Bearer', oandaToken].join(' '),
            'Accept-Encoding': 'gzip,deflate'
        }
    };
    console.log(['requesting', opts.host + opts.path].join(' '));
    var request = https.get(opts, function(_res) {
        if (pause) {
            reqCount++;
            sleep.usleep(Math.floor(150000));
            if (reqCount === 7) {
                sleep.sleep(2);
                reqCount = 0;
            }
        }
        _res.on('end', function(_ret) {
            _def.resolve({
                instrument: instrument,
                granularity: granularity,
                count: count
            });
        });
    });
    request.on('error', function(e) {
        _def.reject(e);
    });
    request.on('response', function(response) {
        var output = fs.createWriteStream(inFile);
        switch (response.headers['content-encoding']) {
            // or, just use zlib.createUnzip() to handle both cases
            case 'gzip':
                response.pipe(zlib.createGunzip()).pipe(output);
                break;
            case 'deflate':
                response.pipe(zlib.createInflate()).pipe(output);
                break;
            default:
                response.pipe(output);
                break;
        }
    });
    return _def.promise;
};
var getMultipleCandles = function(_crosses, _periods, _counts) {
    var requests = [],
        all = null;
    var getCandles = function(req) {
        return requestOandaCandles(req.cross, req.period, undefined, req.count, true);
    };
    for (var c in _crosses) {
        var cross = _crosses[c];
        for (var p in _periods) {
            var period = _periods[p];
            var newPeriod = period,
                newCount = _counts[p] || null;
            if (typeof(_counts) === 'undefined') {
                switch (period) {
                    case 'M15':
                        newPeriod = 'M1';
                        newCount = 15;
                        break;
                    case 'H1':
                        newPeriod = 'M5';
                        newCount = 12;
                        break;
                    case 'H4':
                        newPeriod = 'M15';
                        newCount = 16;
                        break;
                    case 'D':
                        newPeriod = 'H2';
                        newCount = 12;
                        break;
                    case 'W':
                        newPeriod = 'D';
                        newCount = 7;
                        break;
                    case 'M':
                        newPeriod = 'D';
                        newCount = 30;
                        break;
                }
            }
            requests.push({
                cross: cross,
                period: newPeriod,
                count: newCount
            });
        }
    }
    all = q.all(requests.map(getCandles));
    return all;
};
var runRScript = function(scriptName, opts) {
    var fname = [__dirname, '../server/scripts', [scriptName, 'r'].join('.')].join('/');
    console.log('running ' + scriptName);
    opts.path = [__dirname, '../server/socket'].join('/');
    delete opts.host;
    delete opts.port;
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
    fs.readFile(outFile, {}, function(err, data) {
        res.send(data);
    });
    next();
});
var reqCandles = function respond(req, res, next) {
    res.setHeader('content-type', 'text/csv');
    var cross = req.params.cross.replace(/([a-z]{3})([a-z]{3})/gi, '$1_$2').toUpperCase();
    var instrument = /[a-z]{6}/gi.test(req.params.cross) ? cross : req.params.cross.toUpperCase();
    var granularity = req.params.granularity.replace(/[^\w\d]+/gi, '').toUpperCase();
    var outFile = [__dirname + '/../app/data/candles/', cross, '-', req.params.granularity, '.csv'].join('');
    var bImgFile = [__dirname + '/../app/data/breakout/', cross, '-', req.params.granularity, '.jpg'].join('');
    var sinceMinutes = null;
    var startDate = req.params.start;
    switch (req.params.granularity.toUpperCase()) {
        case 'M15':
            sinceMinutes = 15;
            break;
        case 'H1':
            sinceMinutes = 60;
            break;
        case 'H4':
            sinceMinutes = 60 * 4;
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
            var m = granularity.replace(/\M(\d+)/gi, '$1') || null;
            if (m !== null) {
                sinceMinutes = m + 1;
            }
            break;
    }
    // only generate file if it's older than XX minutes
    if (isOutdatedFile(outFile, sinceMinutes)) {
        // retrieve candles
        requestOandaCandles(instrument, granularity, startDate).then(function(inFile) {
            runRScript('main', {
                entryPoint: 'qfxAnalysis',
                data: {
                    instrument: instrument,
                    granularity: granularity,
                    startDate: startDate
                },
                callback: function(err, _res) {
                    // copy on deploy folder
                    sh(['Rscript', __dirname + '/scripts/breakout.r', instrument, granularity].join(' '));
                    sh(['cp', outFile, outFile.replace(/\/app\//g, '/www/')].join(' '));
                    sh(['cp', bImgFile, bImgFile.replace(/\/app\//g, '/www/')].join(' '));
                    fs.readFile(outFile, {}, function(err, data) {
                        res.send(data);
                    });
                }
            });
        }, function(err) {
            console.log(err);
            res.send(err);
        });
    } else {
        if (isOutdatedFile(bImgFile, sinceMinutes)) {
            sh(['Rscript', __dirname + '/scripts/breakout.r', instrument, granularity].join(' '));
        }
        fs.readFile(outFile, {}, function(err, data) {
            res.send(data);
        });
    }
    next();
};
var reqCachedCandles = function respond(req, res, next) {
    res.setHeader('content-type', 'text/csv');
    var cross = req.params.cross.replace(/([a-z]{3})([a-z]{3})/gi, '$1_$2').toUpperCase();
    var instrument = /[a-z]{6}/gi.test(req.params.cross) ? cross : req.params.cross.toUpperCase();
    var granularity = req.params.granularity.replace(/[^\w\d]+/gi, '').toUpperCase();
    var outFile = [__dirname + '/../app/data/candles/', cross, '-', req.params.granularity, '.csv'].join('');
    var bImgFile = [__dirname + '/../app/data/breakout/', cross, '-', req.params.granularity, '.jpg'].join('');
    var sinceMinutes = null;
    switch (req.params.granularity.toUpperCase()) {
        case 'M15':
            sinceMinutes = 15;
            break;
        case 'H1':
            sinceMinutes = 60;
            break;
        case 'H4':
            sinceMinutes = 60 * 4;
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
            var m = granularity.replace(/\M(\d+)/gi, '$1') || null;
            if (m !== null) {
                sinceMinutes = m + 1;
            }
            break;
    }
    fs.readFile(outFile, {}, function(err, data) {
        res.send(data);
    });
    next();
};
server.get('/api/candles/:cross/:start/:granularity', reqCachedCandles);
server.get('/api/candles/all/:granularity', function respond(req, res, next) {
    var granularity = req.params.granularity.replace(/[^\w\d]+/gi, '').toUpperCase();
    var _counts = [96, 168, 180, 365],
        _periods = ['M15', 'H1', 'H4', 'D'],
        ix = _periods.indexOf(granularity);
    getMultipleCandles(crosses.map(function(c) {
        return c.instrument;
    }), [_periods[ix]], [_counts[ix]]).then(function(ret) {
        runRScript('main', {
            entryPoint: 'qfxBatchAnalysis',
            data: {
                granularity: _periods[ix],
                count: _counts[ix]
            },
            callback: function(err, _res) {
                res.send(ret);
            }
        });
    }, function(err) {
        console.log(err);
        res.send(err);
    });
    next();
});
server.get('/api/signals', function respond(req, res, next) {
    res.setHeader('content-type', 'text/csv');
    var outFile = [__dirname + '/../app/data/', 'signal', '.csv'].join('');
    runRScript('main', {
        entryPoint: 'qfxBatchSignals',
        callback: function(err, _res) {
            sh(['cp', outFile, outFile.replace(/\/app\//g, '/www/')].join(' '));
            fs.readFile(outFile, {}, function(err, data) {
                res.send(data);
            });
        }
    });
    next();
});
server.get('/api/marketChange', function respond(req, res, next) {
    res.setHeader('content-type', 'text/csv');
    var outFile = [__dirname + '/../app/data/', 'marketChange', '.csv'].join('');
    runRScript('main', {
        entryPoint: 'qfxMarketChange',
        callback: function(err, _res) {
            sh.run(['cp', outFile, outFile.replace(/\/app\//g, '/www/')].join(' '));
            fs.readFile(outFile, {}, function(err, data) {
                res.send(data);
            });
        }
    });
    next();
});
var reqVolatility = function respond(req, res, next) {
    res.setHeader('content-type', 'text/csv');
    var outFile = [__dirname + '/../app/data/', 'volatility', '.csv'].join('');
    var sinceMinutes = 70;
    var isCron = Boolean(req.params.isCron);
    // only generate file if it's older than XX minutes
    if (isCron && isOutdatedFile(outFile, sinceMinutes)) {
        runRScript('main', {
            entryPoint: 'qfxVolatility',
            callback: function(err, _res) {
                fs.readFile(outFile, {}, function(err, data) {
                    res.send(data);
                });
            }
        });
    } else {
        fs.readFile(outFile, {}, function(err, data) {
            res.send(data);
        });
    }
    next();
};
server.get('/api/candles/volatility', reqVolatility);
server.get('/api/candles/volatility/:isCron', reqVolatility);
var reqCurrencyForce = function respond(req, res, next) {
    res.setHeader('content-type', 'text/csv');
    var outFile = [__dirname + '/../app/data/', 'force', '.csv'].join('');
    var sinceMinutes = 70;
    var isCron = Boolean(req.params.isCron);
    // only generate file if it's older than XX minutes
    if (isCron && isOutdatedFile(outFile, sinceMinutes)) {
        runRScript('main', {
            entryPoint: 'qfxForce',
            callback: function(err, _res) {
                fs.readFile(outFile, {}, function(err, data) {
                    res.send(data);
                });
            }
        });
    } else {
        fs.readFile(outFile, {}, function(err, data) {
            res.send(data);
        });
    }
    next();
};
server.get('/api/currencyForce', reqCurrencyForce);
server.get('/api/currencyForce/:isCron', reqCurrencyForce);
server.get('/api/cot/:month/:year', function respond(req, res, next) {
    var file = [__dirname, '../app/data/cot', ['COT', '-', req.params.month, '-', req.params.year, '.jpg'].join('')].join('/');
    fs.stat(file, function(err, stat) {
        var img = fs.readFileSync(file);
        res.contentType = 'image/jpg';
        res.contentLength = stat.size;
        res.end(img, 'binary');
    });
});
server.get('/api/cot/:cross/:currency1/:currency2', function respond(req, res, next) {
    var instrument = /(?:[a-z]{3}){2}/gi.test(req.params.cross) ? req.params.cross.toUpperCase().replace(/([a-z]{3})([a-z]{3})/gi, '$1_$2') : req.params.cross.toUpperCase();
    var currency1 = req.params.currency1.replace(/[^\w\d\s\.]+/gi, '');
    var currency2 = req.params.currency2.replace(/[^\w\d\s\.]+/gi, '');
    var outFile = [__dirname, '../app/data/cot', [instrument, '.png'].join('')].join('/');
    var sinceMinutes = 61;
    // only generate file if it's older than XX minutes
    if (!fs.existsSync(outFile)) {
        sh(['Rscript', __dirname + '/scripts/positioning.r', instrument, '"' + currency1 + '"', '"' + currency2 + '"'].join(' '));
        sh(['cp', outFile, outFile.replace(/\/app\//g, '/www/')].join(' '));
        fs.stat(outFile, function(err, stat) {
            var img = fs.readFileSync(outFile);
            res.contentType = 'image/png';
            res.contentLength = stat.size;
            res.end(img, 'binary');
        });
    } else {
        fs.stat(outFile, function(err, stat) {
            var img = fs.readFileSync(outFile);
            res.contentType = 'image/png';
            res.contentLength = stat.size;
            res.end(img, 'binary');
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
    var weeks = req.params.weeks ||  52;
    var country1 = req.params.country1 ||  null;
    var country2 = req.params.country2 ||  null;
    var outFile = [__dirname + '/../app/data/', 'calendar', '-', weeks];
    var isCron = Boolean(req.params.isCron);
    var sinceMinutes = 15;
    if (country1 !== null && country2 !== null) {
        outFile = outFile.concat('-' + [country1, country2].join('-'));
    }
    outFile = outFile.concat(['-', 'strength', '.csv']).join('');
    // only generate file if it's older than XX minutes
    if (isCron && isOutdatedFile(outFile, sinceMinutes)) {
        runRScript('main', {
            entryPoint: 'qfxEventsStrength',
            data: {
                weeks: weeks,
                country1: country1,
                country2: country2
            },
            callback: function(err, _res) {
                fs.readFile(outFile, {}, function(err, data) {
                    res.send(data);
                });
            }
        });
    } else {
        fs.readFile(outFile, {}, function(err, data) {
            res.send(data);
        });
    }
    next();
};
server.get('/api/calendar/strength/:weeks/:isCron/:country1/:country2', resCalendarStrength);
server.get('/api/calendar/strength/:weeks/:isCron', resCalendarStrength);
server.get('/api/calendar/strength/:weeks', resCalendarStrength);
server.get('/api/calendar/strength', resCalendarStrength);
server.listen(9999, function() {
    console.log('%s listening at %s', server.name, server.url);
});
