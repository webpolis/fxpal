'use strict';
angular.module('aifxApp').controller('analyticsController', function($scope, $ionicSideMenuDelegate, $http, $ionicLoading, $stateParams, $timeout, $q, ngTableParams, $ionicPopup, $location) {
    $scope.tblEvents = new ngTableParams({}, {
        counts: []
    });
    $scope.nextEvents = null;
    $scope.nxtEvent = null;
    $scope.optsHighchartsCross = {
        scrollbar: {
            enabled: false
        },
        exporting: {
            enabled: false
        },
        options: {
            navigator: {
                enabled: true,
                adaptToUpdatedData: false
            }
        },
        title: {
            text: false
        },
        'series': [{
            name: 'Average Markets Price',
            data: null,
            type: 'candlestick',
            pointInterval: null,
            cursor: 'pointer',
            point: {
                events: {
                    click: function() {
                        var flag = this;
                        $scope.showCandlestickPatterns({
                            x: this.options.x,
                            patterns: $scope.selected.patterns[this.options.x]
                        });
                    }
                }
            },
            id: 'prices'
        }, {
            name: 'Regression',
            data: null,
            type: 'spline',
            pointInterval: null
        }, {
            type: 'flags',
            data: null,
            shape: 'circlepin'
        }, {
            type: 'flags',
            data: null,
            onSeries: 'prices',
            shape: 'url(images/icon-question.png)',
            cursor: 'pointer',
            point: {
                events: {
                    click: function() {
                        var flag = this;
                        $scope.showCandlestickPatterns(flag);
                    }
                }
            }
        }],
        useHighStocks: true,
        'credits': {
            'enabled': false
        },
        xAxis: {
            type: 'datetime'
        }
    };
    $scope.optsHighchartsVolatility = {
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
        },
        xAxis: {
            categories: []
        },
        yAxis: {
            title: {
                text: 'Volatility'
            }
        },
        series: [{
            data: [],
            name: 'Major Crosses',
            cursor: 'pointer',
            type: 'column',
            point: {
                events: {
                    click: function() {
                        var col = this;
                        $timeout(function() {
                            $location.url('/app/cross/' + col.name.replace(/[^a-z]+/gi, ''));
                        }, 50);
                    }
                }
            }
        }],
        title: {
            text: false
        }
    };
    $scope.optsHighchartsStrength = {
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
        xAxis: {
            categories: []
        },
        yAxis: {
            title: {
                text: 'Strength'
            }
        },
        series: [{
            data: [],
            name: 'Major Economies',
        }],
        title: {
            text: false
        },
    };
    $scope.optsHighchartsCurrencyForce = {
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
        },
        xAxis: {
            categories: []
        },
        yAxis: {
            title: {
                text: 'Currency Force'
            }
        },
        series: [{
            data: [],
            name: 'Major Currencies',
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
    Highcharts.setTheme('steel');
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
            $scope.selected.cross1 = $stateParams.cross.split('').splice(0, 3).join('');
            $scope.selected.cross2 = $stateParams.cross.split('').splice(3, 3).join('');
            $scope.selected.cross = jsonPath.eval($scope.data.currencies, '$[?(@.displayName=="' + [$scope.selected.cross1, $scope.selected.cross2].join('/') + '")]')[0] || null;
        }
        var cross = $scope.selected.cross1 + $scope.selected.cross2,
            startDate = moment().subtract('years', 4).format('YYYY-MM-DD'),
            endDate = moment().format('YYYY-MM-DD');
        $ionicLoading.hide();
        if (!angular.isDefined(loadExtras) || loadExtras) {
            $scope.correlated('markets');
            $scope.processEvents().then(function() {
                //$scope.correlated('events');
            });
        }
        if (loadChart) {
            $scope.optChartPeriod = $scope.optsChartPeriods[0];
            $scope.chart($scope.optChartPeriod);
        }
    };
    $scope.computeVolatility = function() {
        $scope.optsHighchartsVolatility.series[0].data = [];
        var tmp = [];
        $ionicLoading.show({
            template: 'Loading...'
        });
        csv2json.csv($scope.config.urls.api + 'candles/volatility', function(data) {
            $scope.selected.volatility = data;
            angular.forEach($scope.selected.volatility, function(cross) {
                tmp.push({
                    name: cross.cross.replace(/_/g, '/'),
                    color: $scope.utils.getRandomColorCode(),
                    y: parseFloat(cross.value)
                });
            });
            $scope.$apply(function() {
                $scope.optsHighchartsVolatility.series[0].data = tmp;
            });
            $ionicLoading.hide();
        });
    };
    $scope.computeCurrencyForce = function() {
        $scope.optsHighchartsCurrencyForce.series[0].data = [];
        var tmp = [];
        var currencies = {};
        $ionicLoading.show({
            template: 'Loading...'
        });
        csv2json.csv($scope.config.urls.api + 'currencyForce', function(data) {
            $scope.selected.currencyForce = data;
            // initialize currencies
            Object.keys(data[0]).map(function(cur) {
                if (cur === 'period') return;
                currencies[cur] = [];
            });
            // fetch period data
            angular.forEach($scope.selected.currencyForce, function(periodData) {
                var period = periodData.period || null;
                if (period === null) return;
                Object.keys(currencies).map(function(cur) {
                    currencies[cur].push(parseFloat(periodData[cur]));
                });
            });
            // build chart
            Object.keys(currencies).map(function(cur) {
                var mean = math.mean(currencies[cur]);
                var mc = jsonPath.eval($scope.config.maps.currency, '$[?(@.code == "' + cur + '")]')[0];
                tmp.push({
                    name: cur,
                    color: $scope.utils.getRandomColorCode(),
                    y: mean,
                    marker: {
                        symbol: 'url(images/flags/' + [angular.lowercase((/em/i.test(mc.country) ? 'europeanunion' : mc.country)), 'png'].join('.') + ')'
                    }
                });
            });
            tmp.sort(function(a, b) {
                if (a.y > b.y) return -1;
                if (a.y < b.y) return 1;
                return 0;
            });
            $scope.$apply(function() {
                $scope.optsHighchartsCurrencyForce.series[0].data = tmp;
            });
            $ionicLoading.hide();
        });
    };
    $scope.computeStrength = function() {
        $scope.optsHighchartsStrength.series[0].data = [];
        var tmp = [];
        $ionicLoading.show({
            template: 'Loading...'
        });
        csv2json.csv($scope.config.urls.api + ['calendar', 'strength', 52].join('/'), function(data) {
            $scope.selected.strength = data;
            angular.forEach($scope.selected.strength, function(row) {
                tmp.push({
                    name: row.country,
                    color: $scope.utils.getRandomColorCode(),
                    y: parseFloat(row.strength),
                    marker: {
                        symbol: 'url(images/flags/' + [angular.lowercase((/em/i.test(row.country) ? 'europeanunion' : row.country)), 'png'].join('.') + ')'
                    }
                });
            });
            $scope.$apply(function() {
                $scope.optsHighchartsStrength.series[0].data = tmp;
            });
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
            case 'monthlyChange':
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
                                var ticker = jsonPath.eval($scope.config.maps.tickers, '$.[?(@.symbol=="' + symbol + '")]')[0] ||  null;
                                try {
                                    if (ticker !== null) {
                                        // set value
                                        jsonPath.eval($scope.selected.correlation.markets, '$[?(@.cross && @.cross == "' + ticker.quandl + '")]')[0][type] = quote.Change && parseFloat(quote.Change) ||  0.0;
                                        // set label
                                        jsonPath.eval($scope.selected.correlation.markets, '$[?(@.cross && @.cross == "' + ticker.quandl + '")]')[0].label = ticker.name;
                                    }
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
        var re = new RegExp('(' + [$scope.selected.cross1, $scope.selected.cross2].join('|') + ')', 'gi');
        return re.test(event.currency);
    };
    $scope.processEvents = function() {
        var def = $q.defer();
        $scope.selected.events = [];
        var maxWeeks = 1;
        // match crosses
        var re = new RegExp('(' + [$scope.selected.cross1, $scope.selected.cross2].join('|') + ')', 'gi');
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
        var startWeekDate = null;
        switch (moment().day()) {
            case 6:
                startWeekDate = moment().add('week', maxWeeks).startOf('week').format('MM-DD-YYYY');
                break;
            case 0:
            case 1:
                startWeekDate = moment().add('week', 0).startOf('week').format('MM-DD-YYYY');
                break;
            default:
                startWeekDate = moment().startOf('week').format('MM-DD-YYYY');
                break;
        }
        var urlsCalendars = Array.apply(null, new Array(maxWeeks)).map(String.valueOf, '').map(function(i, w) {
            var url = $scope.config.urls.events.replace(/\{\{startWeekDate\}\}/gi, startWeekDate);
            return 'http://' + url;
        });
        $http.post($scope.config.urls.api + 'calendar/' + [$scope.selected.cross1, $scope.selected.cross2].join(''), urlsCalendars, {
            cache: true,
            headers: {
                'Content-Type': 'application/json'
            }
        }).success(function(ret) {
            $ionicLoading.hide();
            $scope.selected.events = parseCsv(ret);
            $scope.selected.events = $scope.selected.events.map(function(ev) {
                var o = {}, reCross = new RegExp('^(' + [$scope.selected.cross1, $scope.selected.cross2].join('|') + ')\\s+', 'g');
                for (var p in ev) {
                    o[angular.lowercase(p)] = ev[p];
                    if (/event/gi.test(p)) {
                        o.event = o.event.replace(reCross, '');
                    }
                }
                // convert date to local
                o.localDate = $scope.utils.parseDate([ev.Date, moment().format('YYYY'), ev.Time, ev['Time Zone']].join(' '));
                o.timestamp = moment(o.localDate).valueOf();
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
            // point to next event
            $scope.nextEvents = jsonPath.eval($scope.selected.events, '$[?(@.actual=="" && (@.currency=="' + $scope.selected.cross1 + '" || @.currency=="' + $scope.selected.cross2 + '"))]') ||  null;
            if ($scope.nextEvents !== null) {
                $scope.nextEvents = $scope.nextEvents.filter(function(ev) {
                    return ev.timestamp >= moment().valueOf();
                });
            }
            def.resolve();
        }).error(def.reject);
        return def.promise;
    };
    $scope.correlated = function(target) {
        var curCross = $scope.selected.cross1 + $scope.selected.cross2,
            revCurCross = $scope.selected.cross2 + $scope.selected.cross1;
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
                var corValue = parseFloat(rel.rel);
                rel.rel = corValue;
                return rel;
            });
            $scope.$apply(function() {
                var crosses = [];
                $scope.selected.correlation[target] = correlation.map(function(cor) {
                    // if cross is reverted, we should invert correlation value
                    if (target === 'markets' && (cor.cross1 === revCurCross || cor.cross2 === revCurCross)) {
                        cor.rel = -(cor.rel);
                    } else if (target === 'events' && (cor.cross1 === curCross || cor.cross2 === curCross)) {
                        cor.rel = -(cor.rel);
                    }
                    cor.cross = ((cor.cross1 === curCross && cor.cross2) || (cor.cross1 === revCurCross && cor.cross2)) || ((cor.cross2 === curCross && cor.cross1) || (cor.cross2 === revCurCross && cor.cross1));
                    delete cor.cross1;
                    delete cor.cross2;
                    var curr1 = cor.cross.split('').splice(0, 3).join('');
                    var curr2 = cor.cross.split('').splice(3, 3).join('');
                    // normalize cross
                    var oandaCross = $scope.api.getOandaCross(curr1, curr2) && $scope.api.getOandaCross(curr1, curr2).instrument || null;
                    if (oandaCross !== null) {
                        if (oandaCross.replace(/[^a-z]+/gi, '') !== cor.cross) {
                            // revert rel
                            cor.cross = oandaCross.replace(/[^a-z]+/gi, '');
                            cor.rel = -(cor.rel);
                        }
                    }
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
                    // retrieve change per correlated item
                    var sets = [];
                    angular.forEach($scope.selected.correlation[target], function(cor, k) {
                        if (!(/^[a-z]+\..*$/gi.test(cor.cross))) {
                            //sets.push('QUANDL.' + cor.cross + '.1');
                            $scope.selected.correlation[target][k].currency = true;
                            $scope.selected.correlation[target][k].label = cor.cross;
                        } else {
                            sets.push(cor.cross + '.1');
                        }
                    });
                    if (sets.length === 0) {
                        return;
                    }
                    $scope.computeChange(sets, 'monthlyChange').then(function() {
                        $scope.computeChange(sets, 'weeklyChange').then(function() {
                            $scope.computeChange(null, 'dailyChange');
                        });
                    });
                }
            });
        });
    };
    $scope.chart = function(period) {
        var start = null;
        $scope.selected.granularity = period.granularity ||  null;
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
            instrument: [$scope.selected.cross1, $scope.selected.cross2].join('_'),
            granularity: period.granularity,
            candleFormat: 'bidask',
            start: start,
            end: moment().utc().format($scope.utils.rfc3339)
        };
        $scope.candlesticksAnalysis(optsOanda, period);
    };
    $scope.resetChart = function() {
        $scope.optsHighchartsCross.series[0].data = [];
        $scope.optsHighchartsCross.series[1].data = [];
        $scope.optsHighchartsCross.series[2].data = [];
        $scope.optsHighchartsCross.series[3].data = [];
    };
    $scope.candlesticksAnalysis = function(optsOanda, period) {
        $ionicLoading.show({
            template: 'Loading...'
        });
        $scope.resetChart();
        var isRevertedCross = $scope.api.isRevertedCross($scope.selected.cross1, $scope.selected.cross2);
        // retrieve candles information
        csv2json.csv('data/candlePatterns.csv', function(patterns) {
            $scope.data.patterns = patterns.map(function(pat) {
                pat.Direction = parseInt(pat.Direction);
                return pat;
            });
            csv2json.csv($scope.config.urls.api + ['candles', [$scope.selected.cross1, $scope.selected.cross2].join(''), optsOanda.start.replace(/^([^T]+).*$/gi, '$1'), optsOanda.granularity].join('/'), function(ret) {
                $scope.$apply(function() {
                    $scope.resetChart();
                });
                if (angular.isArray(ret)) {
                    var prevTrendSignal = null,
                        candles = [],
                        trends = [],
                        detectedPatterns = [];
                    angular.forEach(ret, function(row, k) {
                        var time = moment.unix(parseInt(row.Time)).valueOf();
                        // render candles
                        var open = parseFloat(isRevertedCross ? parseFloat(1 / row.Open).toFixed(6) : parseFloat(row.Open).toFixed(6));
                        var close = parseFloat(isRevertedCross ? parseFloat(1 / row.Close).toFixed(6) : parseFloat(row.Close).toFixed(6));
                        var high = parseFloat(isRevertedCross ? parseFloat(1 / row.Low).toFixed(6) : parseFloat(row.High).toFixed(6));
                        var low = parseFloat(isRevertedCross ? parseFloat(1 / row.High).toFixed(6) : parseFloat(row.Low).toFixed(6));
                        var c = new Array(time, open, high, low, close);
                        // render trend signal
                        var renderTrendSignal = true,
                            up = row.UpTrend === '1';
                        if (row.Trend === 'NA' ||  row.NoTrend === '1') {
                            renderTrendSignal = false;
                        } else if (prevTrendSignal !== null) {
                            if ((up && prevTrendSignal.title === 'UP') || (!up && prevTrendSignal.title === 'DOWN')) {
                                renderTrendSignal = false;
                            }
                        }
                        if (renderTrendSignal) {
                            prevTrendSignal = {
                                title: up ? 'UP' : 'DOWN',
                                text: up ? 'UP' : 'DOWN',
                                x: time.valueOf()
                            };
                            trends.push(prevTrendSignal);
                        }
                        // render patterns
                        var patterns = [],
                            hasPattern = false;
                        for (var p in row) {
                            row[p] = parseInt(row[p]);
                            var reCol = new RegExp('Open|High|Low|Close|Volume|UpTrend|NoTrend|DownTrend|Trend|Time', 'i');
                            if (!(reCol.test(p))) {
                                if (!hasPattern && row[p] === 1) {
                                    hasPattern = true;
                                }
                                if (row[p] === 1) {
                                    var pat = {};
                                    var patName = p.replace(/\.\d+/g, '').replace(/([A-Z])|\./g, ' $1').trim().replace(/\s{1,}/g, ' ');
                                    var originalPattern = jsonPath.eval($scope.data.patterns, '$.[?(@.Name == "' + patName + '")]')[0] ||  null;
                                    if (originalPattern !== null) {
                                        patterns.push(originalPattern);
                                    } else {
                                        console.log(patName);
                                    }
                                }
                            }
                        }
                        if (hasPattern) {
                            detectedPatterns.push({
                                title: ' ',
                                x: time.valueOf(),
                                text: 'Patterns detected',
                                patterns: patterns
                            });
                            $scope.selected.patterns[time.valueOf()] = patterns;
                        }
                        candles.push(c);
                    });
                    $scope.$apply(function() {
                        $scope.optsHighchartsCross.series[0].data = candles;
                        $scope.optsHighchartsCross.series[0].pointInterval = period.pointInterval;
                        var linearRegresssion = regression('exponential', $scope.optsHighchartsCross.series[0].data);
                        $scope.optsHighchartsCross.series[1].pointInterval = period.pointInterval;
                        $scope.optsHighchartsCross.series[1].data = linearRegresssion.points;
                        $scope.optsHighchartsCross.series[2].data = trends;
                        $scope.optsHighchartsCross.series[3].data = detectedPatterns;
                        $ionicLoading.hide();
                    });
                }
            });
        });
    };
    $scope.showCandlestickPatterns = function(flag) {
        $scope.selected.flag = flag;
        var scope = $scope.$new();
        var alertPopup = $ionicPopup.alert({
            title: 'Candlestick Patterns',
            templateUrl: 'views/patterns.html',
            scope: scope
        });
        alertPopup.then(function(res) {});
    };
});