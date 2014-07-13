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
        cross2: null
    }, $scope.rootScope = $rootScope;
    $scope.config = {
        token: 'pWGUEdRoPxqEdp66WRYv',
        urls: {
            cross: 'http://www.quandl.com/api/v1/datasets/QUANDL/{{cross}}.json?trim_start={{startDate}}&trim_end={{endDate}}&collapse=daily&auth_token={{token}}',
            multiset: 'http://quandl.com/api/v1/multisets.json?columns={{sets}}&collapse=daily&trim_start={{startDate}}&auth_token={{token}}'
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