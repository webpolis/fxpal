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
            api.getCandlesticks(scope.symbol.label, scope.period, scope.count).then(function(data, isRevertedCross) {
                var diffLast2 = data.candles[0].closeMid - data.candles[1].closeMid;
                switch (scope.period) {
                    case 'D':
                        scope.symbol.dailyChange = isRevertedCross ? -(diffLast2) : diffLast2;
                        break;
                    case 'W':
                        scope.symbol.weeklyChange = isRevertedCross ? -(diffLast2) : diffLast2;
                        break;
                }
            });
        }
    };
});