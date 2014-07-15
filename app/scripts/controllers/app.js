'use strict';
angular.module('aifxApp').controller('appController', function($scope, $ionicSideMenuDelegate, $rootScope, utils) {
    $scope.utils = utils;
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
        crosses: null
    },
    $scope.selected = {
        cross1: null,
        cross2: null,
        correlation: null,
        events: null
    }, $scope.rootScope = $rootScope;
    $scope.config = {
        token: 'pWGUEdRoPxqEdp66WRYv',
        oandaToken: 'ce6b72e81af59be0bbc90152cad8d731-03d41860ed7849e3c4555670858df786',
        urls: {
            cross: 'http://www.quandl.com/api/v1/datasets/QUANDL/{{cross}}.json?trim_start={{startDate}}&trim_end={{endDate}}&collapse=daily&auth_token={{token}}',
            multiset: 'http://quandl.com/api/v1/multisets.json?columns={{sets}}&collapse=daily&trim_start={{startDate}}&auth_token={{token}}',
            cpi: 'http://quandl.com/api/v1/multisets.json?columns=&rows=10',
            rate: 'https://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20yahoo.finance.xchange%20where%20pair%20%3D%20%22{{cross}}%22&format=json&diagnostics=true&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys&callback=',
            candlestick: 'http://api-sandbox.oanda.com/v1/candles?instrument={{cross1}}_{{cross2}}&count={{count}}&candleFormat=midpoint&granularity={{period}}',
            dailyChange: 'http://www.quandl.com/api/v1/multisets.json?columns={{sets}}&collapse=daily&auth_token={{token}}&rows=1&transformation=rdiff&rows=4',
            weeklyChange: 'http://www.quandl.com/api/v1/multisets.json?columns={{sets}}&collapse=weekly&auth_token={{token}}&rows=1&transformation=rdiff&rows=4',
            yahooIndex: 'https://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20yahoo.finance.quoteslist%20where%20symbol%20in%20({{quotes}})&format=json&diagnostics=true&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys&callback=',
            /* events: 'http://calendar.fxstreet.com/eventdate/mini?f=json&culture=en-US&rows=165&pastevents=100&hoursbefore=240&timezone=Argentina+Standard+Time&columns=date%2Ctime%2Cevent%2Cconsensus%2Cprevious%2Cactual&showcountryname=false&countrycode=AU%2CCA%2CJP%3AEMU%2CNZ%2CCH%2CUK%2CUS&isfree=true'*/
            events: 'http://www.dailyfx.com/files/Calendar-{{startWeekDate}}.csv',
            yql: 'https://query.yahooapis.com/v1/public/yql?q={{query}}&format=json&diagnostics=false&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys'
        },
        // used for multiset query
        multiVariables: ['OFDP.FUTURE_B1.1', 'WGC.GOLD_DAILY_USD.1', 'WSJ.CORN_2.1', 'OFDP.SILVER_5.1', 'WSJ.PL_MKT.1', 'WSJ.COPPER.1', 'WSJ.FE_TJN.1', 'WSJ.ZINC.1', 'NIKKEI.INDEX.4', 'YAHOO.INDEX_AORD.4', 'YAHOO.INDEX_GSPTSE.4', 'YAHOO.INDEX_GDAXI.4', 'YAHOO.INDEX_FTSE.4', 'BCB.UDJIAD1.1' /*, 'RATEINF.CPI_USA.1', 'RATEINF.CPI_JPN.1', 'RATEINF.CPI_DEU.1', 'RATEINF.CPI_FRA.1', 'RATEINF.CPI_GBR.1', 'RATEINF.CPI_ITA.1', 'RATEINF.CPI_RUS.1', 'RATEINF.CPI_CAN.1', 'RATEINF.CPI_AUS.1'*/ ],
        correlation: {
            min: 0.71
        },
        yqls: {
            quotes: 'select * from yahoo.finance.quote where symbol in ({{sets}})'
        },
        // keys are tickers used by yql
        maps: {
            tickers: [{
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
                quandl: 'NIKKEI.INDEX',
                symbol: 'N225',
                name: 'NIKKEI'
            }, {
                quandl: 'YAHOO.INDEX_GSPTSE',
                symbol: 'GSPTSE',
                name: 'GSPTSE'
            }, {
                quandl: 'OFDP.SILVER_5',
                symbol: 'SIN14.CMX',
                name: 'SILVER'
            }, {
                quandl: 'WGC.GOLD_DAILY_USD',
                symbol: 'GCN14.CMX',
                name: 'GOLD'
            }, {
                quandl: 'WSJ.COPPER',
                symbol: 'HGN14.CMX',
                name: 'COPPER'
            }, {
                quandl: 'WSJ.CORN_2',
                symbol: 'CU14.CBT',
                name: 'CORN'
            }, {
                quandl: 'WSJ.PL_MKT',
                symbol: 'PLN14.NYM',
                name: 'PLATINUM'
            }, {
                quandl: 'OFDP.FUTURE_B1',
                symbol: 'CLQ14.NYM',
                name: 'OIL'
            }]
        }
    };
    $scope.toggleLeft = function() {
        $ionicSideMenuDelegate.$getByHandle('menuLeft').toggleLeft();
    };
    $scope.init = function() {
        // set token
        $scope.config.urls.cross = $scope.config.urls.cross.replace(/\{\{token\}\}/gi, $scope.config.token);
        $scope.config.urls.multiset = $scope.config.urls.multiset.replace(/\{\{token\}\}/gi, $scope.config.token);
        $scope.config.urls.dailyChange = $scope.config.urls.dailyChange.replace(/\{\{token\}\}/gi, $scope.config.token);
        $scope.config.urls.weeklyChange = $scope.config.urls.weeklyChange.replace(/\{\{token\}\}/gi, $scope.config.token);
        // initialize crosses
        csv2json.csv('data/currencies.csv', function(data) {
            $scope.data.currencies = data;
        });
    };
});