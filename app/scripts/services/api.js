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
angular.module('aifxApp').service('api', function api($http, $q) {
    var sandbox = false,
        oandaToken = 'ce6b72e81af59be0bbc90152cad8d731-03d41860ed7849e3c4555670858df786';
    var apiUrl = sandbox ? 'http://api-sandbox.oanda.com' : 'https://api-fxpractice.oanda.com';
    var urlRate = apiUrl + '/v1/candles?{{params}}&weeklyAlignment=Monday';
    return {
        isRevertedCross: function(cross1, cross2) {
            return jsonPath.eval(oandaCurrencies, '$.[?(@.instrument=="' + [cross1, cross2].join('_') + '")]').length === 0;
        },
        getOandaCross: function(cross1, cross2) {
            var oriCross = [cross1, '_', cross2].join(''),
                revCross = [cross2, '_', cross1].join('');
            var cross = jsonPath.eval(oandaCurrencies, '$.[?(@.instrument=="' + oriCross + '" || @.instrument=="' + revCross + '")]')[0] ||  null;
            return cross;
        },
        getCandlesticks: function(options) {
            var _this = this;
            var def = $q.defer();
            var cross1 = options.instrument.split('_')[0],
                cross2 = options.instrument.split('_')[1];
            var cross = _this.getOandaCross(cross1, cross2);
            cross1 = cross === null ? options.instrument.split('_')[1] : cross1;
            cross2 = cross === null ? options.instrument.split('_')[0] : cross2;
            options.instrument = cross === null ? cross1 + '_' + cross2 : cross.instrument;
            options.candleFormat = angular.isDefined(options.candleFormat) ? options.candleFormat : 'midpoint';
            var params = [];
            for (var p in options) {
                if (options[p] !== null) {
                    params.push(p + '=' + encodeURIComponent(options[p]));
                }
            }
            var url = urlRate.replace(/\{\{params\}\}/gi, params.join('&'));
            $http.get(url, {
                headers: {
                    'Authorization': 'Bearer ' + oandaToken,
                    'Accept': 'application/json'
                },
                cache: true
            }).success(function(data) {
                def.resolve({
                    data: data,
                    isRevertedCross: _this.isRevertedCross(cross1, cross2)
                });
            }).error(def.reject);
            return def.promise;
        }
    };
});