'use strict';
angular.module('aifxApp').controller('portfolioController', function($scope, $ionicSideMenuDelegate, $http, $stateParams, $timeout, $q, $location) {
    $scope.optsHighchartsPortfolio = {
        options: {
            scrollbar: {
                enabled: false
            },
            exporting: {
                enabled: false
            },
            chart: {
                'type': 'column',
                'zoomType': 'x'
            },
            'plotOptions': {
                'series': {
                    'stacking': ''
                }
            }
        },
        xAxis: {
            categories: []
        },
        yAxis: {
            title: {
                text: 'Allocation'
            }
        },
        series: [{
            data: [],
            name: 'Major Crosses',
            cursor: 'pointer',
            point: {
                events: {
                    click: function() {
                        var col = this;
                        $timeout(function() {
                            $location.url('/app/cross/' + col.name);
                        }, 50);
                    }
                }
            }
        }],
        title: {
            text: false
        }
    };
    // not supported via highcharts-ng
    Highcharts.setOptions({
        global: {
            useUTC: false
        }
    });
    $scope.optChartPeriod = null;
    $scope.start = function() {
        $scope.optsHighchartsPortfolio.series[0].data = [];
        var tmp = [];
        csv2json.csv($scope.config.urls.api + 'portfolio', function(data) {
            $scope.selected.portfolio = data;
            angular.forEach($scope.selected.portfolio, function(cross) {
                var cross1 = cross.cross.split('').slice(0, 3).join('');
                var cross2 = cross.cross.split('').slice(3, 6).join('');
                var isRevertedCross = $scope.api.isRevertedCross(cross1, cross2);
                tmp.push({
                    name: !isRevertedCross ? cross.cross : [cross2, cross1].join(''),
                    color: $scope.utils.getRandomColorCode(),
                    y: !isRevertedCross ? parseFloat(cross.percentage) : -(parseFloat(cross.percentage))
                });
            });
            tmp.sort(function(a, b) {
                if (a.y > b.y) {
                    return -1;
                } else {
                    return 1;
                }
                return 0;
            });
            $scope.$apply(function() {
                $scope.optsHighchartsPortfolio.series[0].data = tmp;
            });
        });
    };
});