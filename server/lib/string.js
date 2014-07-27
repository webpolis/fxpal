'use strict';
var natural = require('natural'),
    moment = require('../../bower_components/momentjs/moment.js');
module.exports = {
    normalizeEventName: function(event, currency) {
        var ret = event.trim(),
            months = [];
        for (var m = 0; m < 12; m++) {
            months.push(moment().month(m).format('MMM'));
        }
        currency = currency.length === 6 ? '(?:' + [currency.split('').splice(0, 3), currency.split('').splice(3, 4)].join('|') + ')' : currency;
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
        ret = ret.replace(/\bmian\b/gi, 'mean');
        ret = ret.replace(/.*fed.*pace.*of.*(?:treasury|mbs).*/gi, 'fed pace purchase of treasury');
        ret = ret.replace(/perf\.?\s*of\.?\s*constr\.?(\s*)/gi, 'performance of construction$1');
        ret = ret.replace(/\b(?:mom|yoy|qoq|ytd|mth)\b/gi, '');
        ret = ret.replace(/\d+|[a-z]+\d+|\b[a-z]\b/gi, '');
        // stem
        natural.PorterStemmer.attach();
        ret = ret.tokenizeAndStem().join(' ');
        ret = ret.trim().replace(/[^\w\d]{1,}/g, '_').replace(/^(.*)_[\w\d]{1}$/gi, '$1');
        return ret.toUpperCase();
    }
};