'use strict';
var fs = require('fs'),
    restify = require('restify'),
    moment = require('../bower_components/momentjs/moment.js'),
    server = restify.createServer(),
    sh = require('execSync');
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
        ret = moment().diff(stat.mtime, 'minutes') > sinceMinutes;
    }
    return ret;
};
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
/**
 * Init API server
 */
server.listen(9999, function() {
    console.log('%s listening at %s', server.name, server.url);
});