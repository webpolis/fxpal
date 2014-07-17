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
            var cross1 = scope.symbol.label.split('').splice(0, 3).join(''),
                cross2 = scope.symbol.label.split('').splice(3, 3).join('');
            api.getCandlesticks({
                instrument: cross1 + '_' + cross2,
                granularity: scope.period,
                count: scope.count
            }).then(function(ret) {
                var diffLast2 = ret.data.candles[0].closeMid - ret.data.candles[1].closeMid;
                switch (scope.period) {
                    case 'D':
                        scope.symbol.dailyChange = ret.isRevertedCross ? -(diffLast2) : diffLast2;
                        break;
                    case 'W':
                        scope.symbol.weeklyChange = ret.isRevertedCross ? -(diffLast2) : diffLast2;
                        break;
                }
            });
        }
    };
});