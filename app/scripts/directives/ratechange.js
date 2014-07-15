'use strict';
/**
 *
 * Periods:
 * 
    Top of the minute alignment
        “S5” - 5 seconds
        “S10” - 10 seconds
        “S15” - 15 seconds
        “S30” - 30 seconds
        “M1” - 1 minute
    Top of the hour alignment
        “M2” - 2 minutes
        “M3” - 3 minutes
        “M5” - 5 minutes
        “M10” - 10 minutes
        “M15” - 15 minutes
        “M30” - 30 minutes
        “H1” - 1 hour
    Start of day alignment (default 17:00, Timezone/New York)
        “H2” - 2 hours
        “H3” - 3 hours
        “H4” - 4 hours
        “H6” - 6 hours
        “H8” - 8 hours
        “H12” - 12 hours
        “D” - 1 Day
    Start of week alignment (default Friday)
        “W” - 1 Week
    Start of month alignment (First day of the month)
        “M” - 1 Month

 * @param  {[type]} $interval [description]
 * @param  {[type]} $http     [description]
 * @return {[type]}           [description]
 */
var oandaCurrencies = null;
csv2json.csv('data/oandaCurrencies.csv', function(curr) {
    oandaCurrencies = curr;
});
angular.module('aifxApp').directive('rateChange', function($interval, $http) {
    var urlRate = 'http://api-sandbox.oanda.com/v1/candles?instrument={{cross1}}_{{cross2}}&count={{count}}&candleFormat=midpoint&granularity={{period}}&weeklyAlignment=Monday';
    return {
        template: '<span></span>',
        restrict: 'E',
        scope: {
            symbol: '=',
            period: '@',
            count: '='
        },
        link: function postLink(scope, element, attrs) {
            var cross1 = scope.symbol.label.split('').splice(0, 3).join(''),
                cross2 = scope.symbol.label.split('').splice(3, 3).join('');
            var cross = jsonPath.eval(oandaCurrencies, '$.[?(@.instrument=="' + [cross1, '_', cross2].join('') + '")]')[0] ||  null;
            cross1 = cross === null ? scope.symbol.label.split('').splice(3, 3).join('') : cross1;
            cross2 = cross === null ? scope.symbol.label.split('').splice(0, 3).join('') : cross2;
            var url = urlRate.replace(/\{\{cross1\}\}/gi, cross1).replace(/\{\{cross2\}\}/gi, cross2).replace(/\{\{count\}\}/gi, scope.count).replace(/\{\{period\}\}/gi, scope.period);
            $http.get(url).success(function(data) {
                var diffLast2 = data.candles[0].closeMid - data.candles[1].closeMid;
                switch (scope.period) {
                    case 'D':
                        scope.symbol.dailyChange = cross === null ? -(diffLast2) : diffLast2;
                        break;
                    case 'W':
                        scope.symbol.weeklyChange = cross === null ? -(diffLast2) : diffLast2;;
                        break;
                }
            });
        }
    };
});