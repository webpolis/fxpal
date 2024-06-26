'use strict';
angular.module('aifxApp').directive('rateChange', function($interval, $http, api) {
    return {
        template: '<span></span>',
        restrict: 'E',
        scope: {
            symbol: '=',
            period: '@',
            count: '='
        },
        link: function postLink(scope, element, attrs) {
            var lbl = angular.isObject(scope.symbol) ? scope.symbol.label : scope.symbol;
            var cross1 = lbl.split('').splice(0, 3).join(''),
                cross2 = lbl.split('').splice(3, 3).join('');
            api.getCandlesticks({
                instrument: cross1 + '_' + cross2,
                granularity: scope.period,
                count: scope.count
            }).then(function(ret) {
                var isRevertedCross = api.isRevertedCross(cross1, cross2);
                ret.data.candles.sort(function(a, b) {
                    var da = new Date(a.time);
                    var db = new Date(b.time);
                    if (da > db) {
                        return -1;
                    } else if (da < db) {
                        return 1;
                    }
                    return 0;
                });
                var diffLast2 = ret.data.candles[0].closeMid - ret.data.candles[1].closeMid;
                switch (scope.period) {
                    case 'D':
                        scope.symbol.dailyChange = isRevertedCross ? -(diffLast2) : diffLast2;
                        break;
                    case 'W':
                        scope.symbol.weeklyChange = isRevertedCross ? -(diffLast2) : diffLast2;
                        break;
                    case 'M':
                        scope.symbol.monthlyChange = isRevertedCross ? -(diffLast2) : diffLast2;
                        break;
                }
            });
        }
    };
});