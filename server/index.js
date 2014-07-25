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
var isOutdatedFile = function(fileName, date, sinceMinutes) {
    var ret = true,
        stat = null;
    if (fs.existsSync(fileName)) {
        stat = fs.statSync(fileName);
        ret = moment(date).diff(stat.mtime, 'minutes') > sinceMinutes;
    }
    return ret;
};
/**
 * API methods
 */
server.get('/api/portfolio', function respond(req, res, next) {
    res.setHeader('content-type', 'text/csv');
    var outFile = __dirname + '/../app/data/portfolio.csv',
        stat = null;
    // only generate file if it's older than 1 day
    if (isOutdatedFile(outFile, 60 * 24)) {
        sh.run(['Rscript', __dirname + '/scripts/portfolio.r'].join(' '));
    }
    fs.readFile(outFile, {}, function(err, data) {
        res.send(data);
    });
    next();
});
server.get('/api/trend/:cross/:start/:granularity', function respond(req, res, next) {
    res.send('hello ' + req.params.cross);
    next();
});
/**
 * Init API server
 */
server.listen(9999, function() {
    console.log('%s listening at %s', server.name, server.url);
});