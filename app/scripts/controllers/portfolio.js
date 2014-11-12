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
                tmp.push({
                    name: cross.cross,
                    color: $scope.utils.getRandomColorCode(),
                    y: parseFloat(cross.percentage)
                });
            });
            $scope.$apply(function() {
                $scope.optsHighchartsPortfolio.series[0].data = tmp;
            });
        });
    };
});