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
        },
    };
    // not supported via highcharts-ng
    Highcharts.setOptions({
        global: {
            useUTC: false
        }
    });
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
                $scope.correlated('markets');
                $scope.processEvents().then(function() {
                    $scope.correlated('events');
                });
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
                                        jsonPath.eval($scope.selected.correlation.markets, '$[?(@.cross && @.cross == "' + ix + '")]')[0][type] = val;
                                    } else {
                                        // set currency flag
                                        jsonPath.eval($scope.selected.correlation.markets, '$[?(@.cross && @.cross == "' + ix + '")]')[0].currency = true;
                                    }
                                    // set label
                                    jsonPath.eval($scope.selected.correlation.markets, '$[?(@.cross && @.cross == "' + ix + '")]')[0].label = ix;
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
                                    jsonPath.eval($scope.selected.correlation.markets, '$[?(@.cross && @.cross == "' + ticker.quandl + '")]')[0][type] = parseFloat(quote.Change);
                                    // set label
                                    jsonPath.eval($scope.selected.correlation.markets, '$[?(@.cross && @.cross == "' + ticker.quandl + '")]')[0].label = ticker.name;
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
    $scope.isCurrencyEvent = function(event) {
        var re = new RegExp('(' + [$scope.selected.cross1.currCode, $scope.selected.cross2.currCode].join('|') + ')', 'gi');
        return re.test(event.currency);
    };
    $scope.processEvents = function() {
        var def = $q.defer();
        $scope.selected.events = [];
        var maxWeeks = 4,
            all = [];
        // match crosses
        var re = new RegExp('(' + [$scope.selected.cross1.currCode, $scope.selected.cross2.currCode].join('|') + ')', 'gi');
        var parseCsv = function(csv) {
            var data = [];
            csv2json.csv.parse(csv, function(row) {
                //if (re.test(row.Currency)) {
                row.Currency = angular.uppercase(row.Currency);
                data.push(row);
                //}
            });
            return data;
        };
        $ionicLoading.show({
            template: 'Loading...'
        });
        // retrieve events
        all = Array.apply(null, new Array(maxWeeks)).map(String.valueOf, '').map(function(i, w) {
            var _def = $q.defer();
            var startWeekDate = moment().subtract('week', w).startOf('week').format('MM-DD-YYYY'),
                url = $scope.config.urls.events.replace(/\{\{startWeekDate\}\}/gi, startWeekDate);
            var corsForge = 'http://www.corsproxy.com/';
            $http.get(corsForge + url).success(function(ret) {
                _def.resolve(parseCsv(ret));
            }).error(_def.reject);
            return _def.promise;
        });
        $q.all(all).then(function(ret) {
            $ionicLoading.hide();
            angular.forEach(ret, function(rows) {
                $scope.selected.events = $scope.selected.events.concat(rows);
            });
            $scope.selected.events = $scope.selected.events.map(function(ev) {
                var o = {}, reCross = new RegExp('^(' + [$scope.selected.cross1.currCode, $scope.selected.cross2.currCode].join('|') + ')\\s+', 'g');
                for (var p in ev) {
                    o[angular.lowercase(p)] = ev[p];
                    if (/event/gi.test(p)) {
                        o.event = o.event.replace(reCross, '');
                    }
                }
                // convert date to local
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
            // retrieve event codes
            var eventNames = [];
            angular.forEach($scope.selected.events, function(o) {
                eventNames.push(o.event);
            });
            $http.post($scope.config.urls.api + 'stemmer/' + [$scope.selected.cross1.currCode, $scope.selected.cross2.currCode].join(''), eventNames, {
                cache: true
            }).success(function(codes) {
                if (angular.isArray(codes)) {
                    angular.forEach(codes, function(code, k) {
                        $scope.selected.events[k].code = code;
                    });
                }
                def.resolve();
            });
        }, def.reject);
        return def.promise;
    };
    $scope.correlated = function(target) {
        var curCross = $scope.selected.cross1.currCode + $scope.selected.cross2.currCode,
            revCurCross = $scope.selected.cross2.currCode + $scope.selected.cross1.currCode;
        var file = null;
        switch (target) {
            case 'markets':
                file = 'data/multisetsOutputs.csv';
                break;
            case 'events':
                file = 'data/eventsCrossesOutputs.csv';
                break;
        }
        csv2json.csv(file, function(data) {
            var expr = '$[?(@.cross1=="' + curCross + '" || @.cross2=="' + curCross + '" || @.cross1=="' + revCurCross + '" || @.cross2=="' + revCurCross + '")]';
            var correlation = jsonPath.eval(data, expr).map(function(rel) {
                // if cross is reverted, we should invert correlation value
                var corValue = parseFloat(rel.rel);
                rel.rel = corValue;
                return rel;
            });
            $timeout(function() {
                var crosses = [];
                $scope.selected.correlation[target] = correlation.map(function(cor) {
                    if (target === 'markets' && (cor.cross1 === revCurCross || cor.cross2 === revCurCross)) {
                        cor.rel = -(cor.rel);
                    } else if (target === 'events' && (cor.cross1 === curCross || cor.cross2 === curCross)) {
                        cor.rel = -(cor.rel);
                    }
                    cor.cross = ((cor.cross1 === curCross && cor.cross2) || (cor.cross1 === revCurCross && cor.cross2)) || ((cor.cross2 === curCross && cor.cross1) || (cor.cross2 === revCurCross && cor.cross1));
                    delete cor.cross1;
                    delete cor.cross2;
                    return cor;
                }).filter(function(cor, i, arr) {
                    var ret = (cor.rel >= $scope.config.correlation.min) || (cor.rel <= -($scope.config.correlation.min));
                    ret = ret && crosses.indexOf(cor.cross) === -1;
                    crosses.push(cor.cross);
                    return target !== 'events' ? ret : ret && (cor.rel > -1 && cor.rel < 1);
                });
                $scope.selected.correlation[target].sort(function(a, b) {
                    if (a.rel < b.rel) {
                        return 1;
                    } else if (a.rel > b.rel) {
                        return -1;
                    }
                    return 0;
                });
                if (target === 'markets') {
                    // retrieve daily change per correlated item
                    var sets = [];
                    angular.forEach($scope.selected.correlation[target], function(cor) {
                        if (!(/^[a-z]+\..*$/gi.test(cor.cross))) {
                            sets.push('QUANDL.' + cor.cross + '.1');
                        } else {
                            sets.push(cor.cross + '.1');
                        }
                    });
                    if (sets.length === 0) {
                        return;
                    }
                    $scope.computeChange(sets, 'weeklyChange').then(function() {
                        $scope.computeChange(null, 'dailyChange');
                    });
                }
            }, 150);
        });
    };
    $scope.chart = function(period) {
        $scope.optsHighchartsCross.series[0].data = [];
        var start = null;
        switch (period.label) {
            case 'Intraday':
                switch (moment().day()) {
                    case 6:
                        start = moment().hours(0).subtract('day', 1).utc().format($scope.utils.rfc3339);
                        break;
                    case 0:
                        start = moment().hours(0).subtract('day', 2).utc().format($scope.utils.rfc3339);
                        break;
                    default:
                        start = moment().subtract('day', 1).utc().format($scope.utils.rfc3339);
                        break;
                }
                break;
            case 'Week':
                start = moment().subtract('week', 1).utc().format($scope.utils.rfc3339);
                break;
            case 'Month':
                start = moment().subtract('month', 1).utc().format($scope.utils.rfc3339);
                break;
            case 'Year':
                start = moment().subtract('year', 1).utc().format($scope.utils.rfc3339);
                break;
        }
        var optsOanda = {
            instrument: [$scope.selected.cross1.currCode, $scope.selected.cross2.currCode].join('_'),
            granularity: period.granularity,
            candleFormat: 'bidask',
            start: start,
            end: moment().utc().format($scope.utils.rfc3339)
        };
        $scope.api.getCandlesticks(optsOanda).then(function(ret) {
            if (angular.isDefined(ret.data) && angular.isArray(ret.data.candles)) {
                angular.forEach(ret.data.candles, function(candle) {
                    var time = moment(candle.time).valueOf();
                    var open = parseFloat(ret.isRevertedCross ? (1 / candle.openAsk) : candle.openAsk.toFixed(4));
                    var close = parseFloat(ret.isRevertedCross ? (1 / candle.closeAsk) : candle.closeAsk.toFixed(4));
                    var high = parseFloat(ret.isRevertedCross ? (1 / candle.highAsk) : candle.highAsk.toFixed(4));
                    var low = parseFloat(ret.isRevertedCross ? (1 / candle.lowAsk) : candle.lowAsk.toFixed(4));
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