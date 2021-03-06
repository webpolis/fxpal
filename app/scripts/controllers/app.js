'use strict';
angular.module('aifxApp').controller('appController', function($scope, $ionicSideMenuDelegate, $rootScope, utils, $state, api, $location) {
    $scope.now = new Date();
    $scope.utils = utils, $scope.state = $state, $scope.api = api;
    $scope.data = {
        currencies: null,
        multiset: {
            columns: null,
            data: null
        },
        cross: {
            columns: null,
            data: null
        },
        crosses: null,
        patterns: null,
        marketChange: null
    },
    $scope.selected = {
        cross1: null,
        cross2: null,
        currency1: null, // cot name
        currency2: null,
        cross: null,
        portfolio: null,
        patterns: {},
        granularity: null,
        volatility: null,
        currencyForce: null,
        strength: null,
        correlation: {
            markets: null,
            events: null
        },
        events: null
    }, $scope.rootScope = $rootScope;
    $scope.config = {
        appName: 'qfx.club',
        logoSmall: '<img src="images/logo-s.png" />',
        token: 'pWGUEdRoPxqEdp66WRYv',
        urls: {
            api: 'http://qfx.club:9999/api/',
            //api: 'http://0.0.0.0:9999/api/',
            cross: 'https://www.quandl.com/api/v1/datasets/CURRFX/{{cross}}.json?trim_start={{startDate}}&trim_end={{endDate}}&collapse=daily&auth_token={{token}}',
            multiset: 'https://quandl.com/api/v1/multisets.json?columns={{sets}}&collapse=daily&trim_start={{startDate}}&auth_token={{token}}',
            cpi: 'https://quandl.com/api/v1/multisets.json?columns=&rows=10',
            rate: 'https://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20yahoo.finance.xchange%20where%20pair%20%3D%20%22{{cross}}%22&format=json&diagnostics=true&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys&callback=',
            candlestick: 'http://api-fxpractice.oanda.com/v1/candles?instrument={{cross1}}_{{cross2}}&count={{count}}&candleFormat=midpoint&granularity={{period}}&weeklyAlignment=Monday',
            yahooIndex: 'https://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20yahoo.finance.quoteslist%20where%20symbol%20in%20({{quotes}})&format=json&diagnostics=true&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys&callback=',
            /* events: 'http://calendar.fxstreet.com/eventdate/mini?f=json&culture=en-US&rows=165&pastevents=100&hoursbefore=240&timezone=Argentina+Standard+Time&columns=date%2Ctime%2Cevent%2Cconsensus%2Cprevious%2Cactual&showcountryname=false&countrycode=AU%2CCA%2CJP%3AEMU%2CNZ%2CCH%2CUK%2CUS&isfree=true'*/
            // strip protocol for corsproxy
            events: 'www4.dailyfx.com/files/Calendar-{{startWeekDate}}.csv',
            yql: 'https://query.yahooapis.com/v1/public/yql?q={{query}}&format=json&diagnostics=false&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys'
        },
        correlation: {
            min: 0.7
        },
        yqls: {
            quotes: 'select * from yahoo.finance.quote where symbol in ({{sets}})'
        },
        maps: {
            currency: [{
                country: 'us',
                code: 'USD',
                cot: 'U.S. DOLLAR INDEX'
            }, {
                country: 'nz',
                code: 'NZD',
                cot: 'NEW ZEALAND DOLLAR'
            }, {
                country: 'au',
                code: 'AUD',
                cot: 'AUSTRALIAN DOLLAR'
            }, {
                country: 'ca',
                code: 'CAD',
                cot: 'CANADIAN DOLLAR'
            }, {
                country: 'ch',
                code: 'CHF',
                cot: 'SWISS FRANC'
            }, {
                country: 'jp',
                code: 'JPY',
                cot: 'JAPANESE YEN'
            }, {
                country: 'gb',
                code: 'GBP',
                cot: 'BRITISH POUND STERLING'
            }, {
                country: 'em',
                code: 'EUR',
                cot: 'EURO FX'
            }, {
                country: 'cn',
                code: 'HKD',
                cot: 'HONG KONG DOLLAR'
            }],
            tickers: [{
                quandl: 'NIKKEI.INDEX',
                symbol: 'N225',
                name: 'NIKKEI'
            }, {
                quandl: 'LBMA.SILVER',
                symbol: 'SIN14.CMX',
                name: 'SILVER'
            }, {
                quandl: 'BUNDESBANK.BBK01_WT5511',
                symbol: 'GCN14.CMX',
                name: 'GOLD'
            }, {
                quandl: 'OFDP.COPPER_6',
                symbol: 'HGN14.CMX',
                name: 'COPPER'
            }, {
                quandl: 'WSJ.CORN_2',
                symbol: 'CU14.CBT',
                name: 'CORN'
            }, {
                quandl: 'LPPM.PLAT',
                symbol: 'PLN14.NYM',
                name: 'PLATINUM'
            }, {
                quandl: 'DOE.RWTC',
                symbol: 'CLQ14.NYM',
                name: 'OIL'
            }, {
                quandl: 'NASDAQOMX.NDX',
                symbol: 'CLQ14.NYM',
                name: 'NASDAQ'
            }, {
                quandl: 'BCB.UDJIAD1',
                symbol: 'CLQ14.NYM',
                name: 'DOW JONES'
            }, {
                quandl: 'YAHOO.INDEX_GDAXI',
                symbol: 'GDAXI',
                name: 'DAX'
            }, {
                quandl: 'YAHOO.INDEX_FTSE',
                symbol: 'FTSE',
                name: 'FTSE'
            }, {
                quandl: 'YAHOO.INDEX_AORD',
                symbol: 'AORD',
                name: 'AORD'
            }, {
                quandl: 'YAHOO.INDEX_SSEC',
                symbol: 'SSEC',
                name: 'SSEC'
            }, {
                quandl: 'YAHOO.INDEX_GSPC',
                symbol: 'GSPC',
                name: 'GSPC'
            }, {
                quandl: 'YAHOO.INDEX_FCHI',
                symbol: 'FCHI',
                name: 'FCHI'
            }, {
                quandl: 'YAHOO.INDEX_GSPTSE',
                symbol: 'GSPTSE',
                name: 'GSPTSE'
            }]
        }
    };
    $scope.$watch('selected.cross', function(n, o) {
        if (angular.isDefined(n) && n !== null) {
            var crosses = n.displayName.split('/');
            $scope.selected.cross1 = crosses[0];
            $scope.selected.cross2 = crosses[1];
            $scope.selected.currency1 = jsonPath.eval($scope.config.maps.currency, '$[?(@.code == "' + $scope.selected.cross1 + '")]')[0].cot ||  null;
            $scope.selected.currency2 = jsonPath.eval($scope.config.maps.currency, '$[?(@.code == "' + $scope.selected.cross2 + '")]')[0].cot ||  null;
            $location.url('/app/cross/' + $scope.selected.cross1 + $scope.selected.cross2);
        } else {
            $scope.selected.cross1 = $scope.selected.cross2 = null;
        }
    });
    $scope.toggleLeft = function() {
        $ionicSideMenuDelegate.$getByHandle('menuLeft').toggleLeft();
    };
    $scope.init = function() {
        // set token for quandl
        for (var p in $scope.config.urls) {
            $scope.config.urls[p] = $scope.config.urls[p].replace(/\{\{token\}\}/gi, $scope.config.token);
        }
        // initialize crosses
        csv2json.csv('data/availableCrosses.csv', function(data) {
            $scope.data.currencies = data;
        });
    };
    $scope.getRandom = function() {
        return Math.ceil(Math.random() + Date.now());
    };
});