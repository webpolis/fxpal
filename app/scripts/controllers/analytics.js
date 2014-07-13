'use strict';
angular.module('aifxApp').controller('analyticsController', function($scope, $ionicSideMenuDelegate, $http, $ionicLoading) {
    $scope.start = function() {
        $ionicLoading.show({
            template: 'Loading...'
        });
        var cross = $scope.selected.cross1.currCode + $scope.selected.cross2.currCode,
            startDate = moment().subtract('years', 4).format('YYYY-MM-DD'),
            endDate = moment().format('YYYY-MM-DD');
        $http.get($scope.config.urls.cross.replace(/\{\{cross\}\}/gi, cross).replace(/\{\{startDate\}\}/gi, startDate).replace(/\{\{endDate\}\}/gi, endDate)).success(function(ret) {
            if (angular.isArray(ret.column_names) && angular.isArray(ret.data)) {
                $scope.data.cross.columns = ret.column_names;
                $scope.data.cross.data = ret.data;
            }
            $scope.multiset();
        }).error(function(err) {
            $ionicLoading.hide();
        });
    };
    $scope.multiset = function() {
        $ionicLoading.show({
            template: 'Loading...'
        });
        var startDate = moment().subtract('years', 4).format('YYYY-MM-DD');
        // build crosses
        var crosses = [],
            i = 0,
            finalCrosses = [];
        angular.forEach($scope.data.currencies, function(cur) {
            crosses.push(cur.currCode);
        });
        crosses.sort();
        var crossesRev = angular.copy(crosses);
        crossesRev.reverse();
        angular.forEach(crosses, function(c, k) {
            angular.forEach(crossesRev, function(cc, kk) {
                var ccc = c + cc;
                if (c !== cc && finalCrosses.indexOf(cc + c) === -1) {
                    finalCrosses.push(ccc);
                }
            });
        });
        $scope.data.crosses = finalCrosses;
        // build multiset url
        var sets = $scope.data.crosses.map(function(cross) {
            return ['QUANDL.' + cross + '.1'].join(',');
        }).concat($scope.config.commodities).join(',');
        // retrieve multiset
        $http.get($scope.config.urls.multiset.replace(/\{\{sets\}\}/gi, sets).replace(/\{\{startDate\}\}/gi, startDate)).success(function(ret) {
            if (angular.isArray(ret.column_names) && angular.isArray(ret.data)) {
                $scope.data.multiset.columns = ret.column_names;
                $scope.data.multiset.data = ret.data;
            }
            $ionicLoading.hide();
        });
    };
});