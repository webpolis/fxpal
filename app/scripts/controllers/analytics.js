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
            $scope.correlated();
            $ionicLoading.hide();
            $scope.processEvents();
            //$scope.multiset();
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
        }).concat($scope.config.multiVariables).join(',');
        // retrieve multiset
        $http.get($scope.config.urls.multiset.replace(/\{\{sets\}\}/gi, sets).replace(/\{\{startDate\}\}/gi, startDate)).success(function(ret) {
            if (angular.isArray(ret.column_names) && angular.isArray(ret.data)) {
                $scope.data.multiset.columns = ret.column_names;
                $scope.data.multiset.data = ret.data;
            }
            $ionicLoading.hide();
        });
    };
    $scope.computeChange = function(sets, type) {
        $ionicLoading.show({
            template: 'Loading...'
        });
        $http.get($scope.config.urls[type].replace(/\{\{sets\}\}/gi, sets.join(','))).success(function(ret) {
            // update correlated items and set change
            var change = {};
            if (angular.isArray(ret.column_names) && angular.isArray(ret.data)) {
                angular.forEach(ret.column_names, function(col, k) {
                    if (k === 0) {
                        // avoid date col
                        return;
                    }
                    change[col.replace(/^(?:QUANDL\.)?([^\s]+).*$/gi, '$1')] = null;
                });
                // get non null values
                var keys = Object.keys(change);
                angular.forEach(ret.data, function(d, kk) {
                    angular.forEach(d, function(val, kkk) {
                        if (kkk === 0) {
                            // avoid date col
                            return;
                        }
                        if (val !== null && change[keys[kkk - 1]] === null) {
                            var ix = keys[kkk - 1];
                            change[ix] = val;
                            jsonPath.eval($scope.selected.correlation, '$[?(@.cross1 && @.cross1 == "' + ix + '" || @.cross2 && @.cross2 == "' + ix + '")]')[0][type] = val;
                        }
                    });
                });
            }
            $ionicLoading.hide();
        });
    };
    $scope.processEvents = function() {
        $scope.selected.events = [];
        // match crosses
        var re = new RegExp('(' + [$scope.selected.cross1.currCode, $scope.selected.cross2.currCode].join('|') + ')', 'gi');
        var parseCsv = function(csv) {
            csv2json.csv.parse(csv.contents, function(row) {
                if (re.test(row.Currency)) {
                    $scope.selected.events.push(row);
                }
            });
            $ionicLoading.hide();
        };
        for (var w = 0; w < 4; w++) {
            $ionicLoading.show({
                template: 'Loading...'
            });
            var startWeekDate = moment().subtract('week', w).startOf('week').format('MM-DD-YYYY'),
                url = $scope.config.urls.events.replace(/\{\{startWeekDate\}\}/gi, startWeekDate);
            $.getJSON('http://whateverorigin.org/get?url=' + url + '&callback=?', parseCsv);
        }
    };
    $scope.correlated = function() {
        var curCross = $scope.selected.cross1.currCode + $scope.selected.cross2.currCode,
            revCurCross = $scope.selected.cross2.currCode + $scope.selected.cross1.currCode;
        csv2json.csv('data/correlCrosses.csv', function(data) {
            var expr = '$[?(@.cross1=="' + curCross + '" || @.cross2=="' + curCross + '" || @.cross1=="' + revCurCross + '" || @.cross2=="' + revCurCross + '")]';
            var correlation = jsonPath.eval(data, expr).map(function(rel) {
                // if cross is reverted, we should invert correlation value
                var corValue = parseFloat(rel.rel);
                if (rel.cross1 === revCurCross || rel.cross2 === revCurCross) {
                    corValue = -(corValue);
                }
                rel.rel = corValue;
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
                // retrieve daily change per correlated item
                var sets = [];
                angular.forEach($scope.selected.correlation, function(cor) {
                    var cross = cor.cross1 || cor.cross2;
                    if (!(/^[a-z]+\..*$/gi.test(cross))) {
                        sets.push('QUANDL.' + cross + '.1');
                    } else {
                        sets.push(cross + '.1');
                    }
                });
                if (sets.length === 0) {
                    return;
                }
                $scope.computeChange(sets, 'dailyChange');
                $scope.computeChange(sets, 'weeklyChange');
            }, 150);
        });
    };
});