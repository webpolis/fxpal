'use strict';
angular.module('aifxApp').service('utils', function utils() {
    return {
        rfc3339: 'YYYY-MM-DDTHH:mm:ssZ',
        parseDate: function(dateString) {
            return moment(dateString).zone(moment().zone()).toDate();
        },
        formatDate: function(dateString, format) {
            format = format || this.rfc3339;
            return moment(dateString).zone(moment().zone()).format(format);
        },
        normalizeEventName: function(event, currency) {
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
            ret = ret.replace(/perf\.?\s*of\.?\s*constr\.?(\s*)/gi, 'performance of construction$1');
            ret = ret.trim().replace(/[^\w\d]{1,}/g, '_');
            return ret.toUpperCase();
        }
    };
});