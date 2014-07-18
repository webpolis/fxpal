'use strict';
var fs = require('fs'),
    pathDatasets = __dirname + '/../../app/data/';
var datasets = fs.readdirSync(pathDatasets),
    calendars = [];
if (datasets.length > 0) {
    datasets.forEach(function(d, i) {
        if (/^calendar.*\.csv/gi.test(d)) {
            calendars.push(pathDatasets + d);
        }
    });
}
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

