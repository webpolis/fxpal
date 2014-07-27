'use strict';
angular.module('aifxApp').controller('portfolioController', function($scope, $ionicSideMenuDelegate, $http, $ionicLoading, $stateParams, $timeout, $q) {
    $scope.optsHighchartsPortfolio = {
        options: {
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
            name: 'Major Crosses'
        }],
        exporting: {
            enabled: false
        },
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
        $ionicLoading.show({
            template: 'Loading...'
        });
        csv2json.csv($scope.config.urls.api + 'portfolio', function(data) {
            $scope.selected.portfolio = data;
            angular.forEach($scope.selected.portfolio, function(cross) {
                $scope.optsHighchartsPortfolio.series[0].data.push({
                    name: cross.cross,
                    color: $scope.utils.getRandomColorCode(),
                    y: parseFloat(cross.percentage)
                });
            });
            $ionicLoading.hide();
        });
    };
});