'use strict';
angular.module('aifxApp').controller('appController', function($scope, $ionicSideMenuDelegate) {
    $scope.data = {
        currencies: null
    };
    $scope.toggleLeft = function() {
        $ionicSideMenuDelegate.$getByHandle('menuLeft').toggleLeft();
    };
    $scope.init = function() {
        csv2json.csv('data/currencies.csv', function(data) {
            $scope.data.currencies = data;
        });
    };
});