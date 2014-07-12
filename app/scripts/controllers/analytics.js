'use strict';
angular.module('aifxApp').controller('analyticsController', function($scope, $ionicSideMenuDelegate, $http, $ionicLoading) {
    $scope.start = function() {
        $ionicLoading.show({
            template: 'Loading...'
        });
        var cross = $scope.selected.cross1['Alphabetic Code'] + $scope.selected.cross2['Alphabetic Code'],
            startDate = moment().subtract('years', 3).format('YYYY-MM-DD'),
            endDate = moment().format('YYYY-MM-DD');
        $http.get($scope.config.urls.cross.replace(/\{\{cross\}\}/gi, cross).replace(/\{\{startDate\}\}/gi, startDate).replace(/\{\{endDate\}\}/gi, endDate)).success(function(ret) {
            if (angular.isArray(ret.column_names) && angular.isArray(ret.data)) {
                $scope.data.cross.columns = ret.column_names;
                $scope.data.cross.data = ret.data;
            }
            $scope.correlation();
            $ionicLoading.hide();
        }).error(function(err) {
            $ionicLoading.hide();
        });
    };
    $scope.correlation = function() {
        /**
         * http://quandl.com/api/v1/multisets.csv?columns=QUANDL.USDJPY.1,QUANDL.USDJPY.2,QUANDL.EURJPY.1,QUANDL.EURJPY.2&collapse=daily&auth_token=pWGUEdRoPxqEdp66WRYv
         */
        var startDate = moment().subtract('years', 3).format('YYYY-MM-DD');
        // build crosses
        var crosses = [],
            i = 0,
            finalCrosses = [];
        angular.forEach($scope.data.currencies, function(cur) {
            crosses.push(cur['Alphabetic Code']);
        });
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
    };
});