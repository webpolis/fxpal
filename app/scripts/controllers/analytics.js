'use strict';
angular.module('aifxApp').controller('analyticsController', function($scope, $ionicSideMenuDelegate, $http, $ionicLoading, $stateParams, $timeout, $q, ngTableParams) {
    $scope.tblEvents = new ngTableParams({}, {
        counts: []
    });
    $scope.optsHighchartsCross = {
        exporting: {
            enabled: false
        },
        title: {
            text: false
        },
        'series': [{
            name: 'Average Markets Price',
            data: null,
            type: 'candlestick',
            pointInterval: null
        }, {
            name: 'Regression',
            data: null,
            type: 'spline',
            pointInterval: null
        }],
        useHighStocks: true,
        'credits': {
            'enabled': false
        },
        xAxis: {
            type: 'datetime'
        }
    };
    $scope.optsChartPeriods = [{
        label: 'Intraday',
        granularity: 'M15',
        pointInterval: 900000
    }, {
        label: 'Week',
        granularity: 'H1',
        pointInterval: 3600000
    }, {
        label: 'Month',
        granularity: 'H4',
        pointInterval: 14400000
    }, {
        label: 'Year',
        granularity: 'D',
        pointInterval: 86400000
    }];
    $scope.optChartPeriod = null;
    $scope.start = function(loadExtras, loadChart) {
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
            $ionicLoading.hide();
            if (!angular.isDefined(loadExtras) || loadExtras) {
                $scope.correlated();
                $scope.processEvents();
            }
            if (loadChart) {
                $scope.optChartPeriod = $scope.optsChartPeriods[0];
                $scope.chart($scope.optChartPeriod);
            }
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
        }).concat($scope.config.maps.tickers.map(function(ticker) {
            return ticker.quandl;
        })).join(',');
        // retrieve multiset
        $http.get($scope.config.urls.multiset.replace(/\{\{sets\}\}/gi, sets).replace(/\{\{startDate\}\}/gi, startDate)).success(function(ret) {
            if (angular.isArray(ret.column_names) && angular.isArray(ret.data)) {
                $scope.data.multiset.columns = ret.column_names;
                $scope.data.multiset.data = ret.data;
            }
            $ionicLoading.hide();
        });
    };
    /**
     * we only process commodities & indexes here; currencies are handled by rateChange directive
     *
     * @param  {[type]} sets [description]
     * @param  {[type]} type [description]
     * @return {[type]}      [description]
     */
    $scope.computeChange = function(sets, type) {
        var def = $q.defer();
        $ionicLoading.show({
            template: 'Loading...'
        });
        switch (type) {
            case 'weeklyChange':
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
                                    var ticker = jsonPath.eval($scope.config.maps.tickers, '$.[?(@.quandl=="' + ix + '")]')[0] ||  false;
                                    if (ticker) {
                                        change[ix] = val;
                                        // set value
                                        jsonPath.eval($scope.selected.correlation, '$[?(@.cross1 && @.cross1 == "' + ix + '" || @.cross2 && @.cross2 == "' + ix + '")]')[0][type] = val;
                                    } else {
                                        // set currency flag
                                        jsonPath.eval($scope.selected.correlation, '$[?(@.cross1 && @.cross1 == "' + ix + '" || @.cross2 && @.cross2 == "' + ix + '")]')[0].currency = true;
                                    }
                                    // set label
                                    jsonPath.eval($scope.selected.correlation, '$[?(@.cross1 && @.cross1 == "' + ix + '" || @.cross2 && @.cross2 == "' + ix + '")]')[0].label = ix;
                                }
                            });
                        });
                    }
                    $ionicLoading.hide();
                    def.resolve();
                }).error(function(err) {
                    $ionicLoading.hide();
                    def.reject(err);
                });
                break;
            case 'dailyChange':
                var tickers = $scope.config.maps.tickers.map(function(ticker) {
                    var symbol = '"' + (/\./g.test(ticker.symbol) ? ticker.symbol : '^' + ticker.symbol) + '"';
                    return symbol;
                });
                var symbols = $scope.config.yqls.quotes.replace(/\{\{sets\}\}/gi, tickers.join(','));
                $http.get($scope.config.urls.yql.replace(/\{\{query\}\}/gi, encodeURIComponent(symbols))).success(function(ret) {
                    if (angular.isDefined(ret.query) && angular.isObject(ret.query.results)) {
                        if (angular.isArray(ret.query.results.quote)) {
                            angular.forEach(ret.query.results.quote, function(quote) {
                                var symbol = quote.Symbol.replace(/\^/g, '');
                                var ticker = jsonPath.eval($scope.config.maps.tickers, '$.[?(@.symbol=="' + symbol + '")]')[0];
                                try {
                                    // set value
                                    jsonPath.eval($scope.selected.correlation, '$[?(@.cross1 && @.cross1 == "' + ticker.quandl + '" || @.cross2 && @.cross2 == "' + ticker.quandl + '")]')[0][type] = parseFloat(quote.Change);
                                    // set label
                                    jsonPath.eval($scope.selected.correlation, '$[?(@.cross1 && @.cross1 == "' + ticker.quandl + '" || @.cross2 && @.cross2 == "' + ticker.quandl + '")]')[0].label = ticker.name;
                                } catch (err) {}
                            });
                        }
                    }
                    $ionicLoading.hide();
                    def.resolve();
                }).error(function(err) {
                    $ionicLoading.hide();
                    def.reject(err);
                });
                break;
        }
        return def.promise;
    };
    $scope.processEvents = function() {
        $scope.selected.events = [];
        var maxWeeks = 6,
            all = [];
        // match crosses
        var re = new RegExp('(' + [$scope.selected.cross1.currCode, $scope.selected.cross2.currCode].join('|') + ')', 'gi');
        var parseCsv = function(csv) {
            var data = [];
            csv2json.csv.parse(csv.contents, function(row) {
                if (re.test(row.Currency)) {
                    data.push(row);
                }
            });
            return data;
        };
        $ionicLoading.show({
            template: 'Loading...'
        });
        // retrieve events
        all = Array.apply(null, new Array(maxWeeks)).map(String.valueOf, '').map(function(i, w) {
            var def = $q.defer();
            var startWeekDate = moment().subtract('week', w).startOf('week').format('MM-DD-YYYY'),
                url = $scope.config.urls.events.replace(/\{\{startWeekDate\}\}/gi, startWeekDate);
            $http.jsonp('http://whateverorigin.org/get?url=' + url + '&callback=JSON_CALLBACK').success(function(ret) {
                def.resolve(parseCsv(ret));
            }).error(def.reject);
            return def.promise;
        });
        $q.all(all).then(function(ret) {
            $ionicLoading.hide();
            angular.forEach(ret, function(rows) {
                $scope.selected.events = $scope.selected.events.concat(rows);
            });
            // convert date to local
            $scope.selected.events = $scope.selected.events.map(function(ev) {
                var o = {}, reCross = new RegExp('^(' + [$scope.selected.cross1.currCode, $scope.selected.cross2.currCode].join('|') + ')\\s+', 'g');
                for (var p in ev) {
                    o[angular.lowercase(p)] = ev[p];
                    if (/event/gi.test(p)) {
                        o.event = o.event.replace(reCross, '');
                    }
                }
                o.localDate = $scope.utils.parseDate([ev.Date, moment().format('YYYY'), ev.Time, ev['Time Zone']].join(' '));
                return o;
            }).filter(function(ev) {
                return ev.actual !== '' ||  ev.forecast !== '' ||  ev.previous !== '';
            });
            // sort by date asc
            $scope.selected.events.sort(function(a, b) {
                if (new Date(a.localDate) < new Date(b.localDate)) {
                    return -1;
                } else if (new Date(a.localDate) > new Date(b.localDate)) {
                    return 1;
                }
                return 0;
            });
        });
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
                $scope.computeChange(sets, 'weeklyChange').then(function() {
                    $scope.computeChange(null, 'dailyChange');
                });
            }, 150);
        });
    };
    $scope.chart = function(period) {
        $scope.optsHighchartsCross.series[0].data = [];
        var curCross = $scope.selected.cross1.currCode + $scope.selected.cross2.currCode,
            bars = 0;
        switch (period.label) {
            case 'Intraday':
                bars = 96;
                break;
            case 'Week':
                bars = 168;
                break;
            case 'Month':
                bars = 186;
                break;
            case 'Year':
                bars = 365;
                break;
        }
        $scope.api.getCandlesticks(curCross, period.granularity, bars, false).then(function(ret) {
            if (angular.isDefined(ret.data) && angular.isArray(ret.data.candles)) {
                angular.forEach(ret.data.candles, function(candle) {
                    var time = moment(candle.time).valueOf();
                    var open = ret.isRevertedCross ? 1 / candle.openAsk : candle.openAsk;
                    var close = ret.isRevertedCross ? 1 / candle.closeAsk : candle.closeAsk;
                    var high = ret.isRevertedCross ? 1 / candle.highAsk : candle.highAsk;
                    var low = ret.isRevertedCross ? 1 / candle.lowAsk : candle.lowAsk;
                    var c = new Array(time, open, high, low, close);
                    $scope.optsHighchartsCross.series[0].data.push(c);
                });
                $scope.optsHighchartsCross.series[0].pointInterval = period.pointInterval;
                var linearRegresssion = regression('exponential', $scope.optsHighchartsCross.series[0].data);
                $scope.optsHighchartsCross.series[1].pointInterval = period.pointInterval;
                $scope.optsHighchartsCross.series[1].data = linearRegresssion.points;
            }
        });
    };
});