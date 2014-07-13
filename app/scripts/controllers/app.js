'use strict';
angular.module('aifxApp').controller('appController', function($scope, $ionicSideMenuDelegate, $rootScope) {
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
        correlation: null
    }, $scope.rootScope = $rootScope;
    $scope.config = {
        token: 'pWGUEdRoPxqEdp66WRYv',
        urls: {
            cross: 'http://www.quandl.com/api/v1/datasets/QUANDL/{{cross}}.json?trim_start={{startDate}}&trim_end={{endDate}}&collapse=daily&auth_token={{token}}',
            multiset: 'http://quandl.com/api/v1/multisets.json?columns={{sets}}&collapse=daily&trim_start={{startDate}}&auth_token={{token}}'
        },
        // used for multiset query
        commodities: ['OFDP.FUTURE_B1.1', 'WGC.GOLD_DAILY_USD.1', 'WSJ.CORN_2.1', 'OFDP.SILVER_5.1', 'WSJ.PL_MKT.1', 'WSJ.COPPER.1', 'WSJ.FE_TJN.1', 'WSJ.ZINC.1', 'NIKKEI.INDEX.4', 'YAHOO.INDEX_AORD.4', 'YAHOO.INDEX_GSPTSE.4', 'YAHOO.INDEX_GDAXI.4', 'YAHOO.INDEX_FTSE.4', 'BCB.UDJIAD1.1'],
        correlation: {
            min: 0.77
        }
    };
    $scope.toggleLeft = function() {
        $ionicSideMenuDelegate.$getByHandle('menuLeft').toggleLeft();
    };
    $scope.init = function() {
        // set token
        $scope.config.urls.cross = $scope.config.urls.cross.replace(/\{\{token\}\}/gi, $scope.config.token);
        $scope.config.urls.multiset = $scope.config.urls.multiset.replace(/\{\{token\}\}/gi, $scope.config.token);
        // initialize crosses
        csv2json.csv('data/currencies.csv', function(data) {
            $scope.data.currencies = data;
        });
    };
});