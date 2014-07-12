'use strict';
angular.module('aifxApp').controller('analyticsController', function($scope, $ionicSideMenuDelegate, $http) {
    $scope.start = function() {
        var cross = $scope.selected.cross1['Alphabetic Code'] + $scope.selected.cross2['Alphabetic Code'],
            startDate = moment().subtract('years', 2).format('YYYY-MM-DD'),
            endDate = moment().format('YYYY-MM-DD');
        $http.get($scope.config.urls.cross.replace(/\{\{cross\}\}/gi, cross).replace(/\{\{startDate\}\}/gi, startDate).replace(/\{\{endDate\}\}/gi, endDate)).success(function(ret) {
            if (angular.isArray(ret.column_names) && angular.isArray(ret.data)) {
                $scope.data.cross.columns = ret.column_names;
                $scope.data.cross.data = ret.data;
            }
        });
    };
});