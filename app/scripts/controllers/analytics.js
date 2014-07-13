'use strict';
angular.module('aifxApp').controller('analyticsController', function($scope, $ionicSideMenuDelegate, $http, $ionicLoading, $stateParams, $timeout) {
    $scope.start = function() {
        $ionicLoading.show({
            template: 'Loading...'
        });
        // set cross via param
        if (angular.isDefined($stateParams.cross)) {
            $scope.selected.cross1 = jsonPath.eval($scope.data.currencies, '$[?(@.currCode=="' + $stateParams.cross.split('').splice(0, 3).join('') + '")]')[0];
            $scope.selected.cross2 = jsonPath.eval($scope.data.currencies, '$[?(@.currCode=="' + $stateParams.cross.split('').splice(3, 3).join('') + '")]')[0];
        }
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
            $scope.correlated();
            $ionicLoading.hide();
        });
    };
    $scope.correlated = function() {
        var curCross = $scope.selected.cross1.currCode + $scope.selected.cross2.currCode,
            revCurCross = $scope.selected.cross2.currCode + $scope.selected.cross1.currCode;
        csv2json.csv('data/correlCrosses.csv', function(data) {
            var expr = '$[?(@.cross1=="' + curCross + '" || @.cross2=="' + curCross + '" || @.cross1=="' + revCurCross + '" || @.cross2=="' + revCurCross + '")]';
            var correlation = jsonPath.eval(data, expr).map(function(rel) {
                rel.rel = parseFloat(rel.rel);
                return rel;
            });
            correlation.sort(function(a, b) {
                if (a.rel < b.rel) {
                    return 1;
                } else if (a.rel > b.rel) {
                    return -1;
                }
                return 0;
            });
            $timeout(function() {
                $scope.selected.correlation = correlation.map(function(cor) {
                    if (cor.cross1 === curCross || cor.cross1 === revCurCross) {
                        delete cor.cross1;
                    } else if (cor.cross2 === curCross || cor.cross2 === revCurCross) {
                        delete cor.cross2;
                    }
                    return cor;
                }).filter(function(cor) {
                    return ((cor.rel >= $scope.config.correlation.min) || (cor.rel <= -($scope.config.correlation.min)));
                });
            }, 150);
        });
    };
});