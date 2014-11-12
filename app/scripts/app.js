'use strict';
// error handling
window.onerror = function(msg, url, line) {
    console.log('Caught[via window.onerror]: ' + msg + ' from ' + url + ':' + line);
    return true;
};
window.addEventListener('error', function(evt) {
    console.log('Caught[via error event]:  ' + evt.message + ' from ' + evt.filename + ':' + evt.lineno);
    console.log(evt);
    evt.preventDefault();
});
// setup angular
angular.module('aifxApp', ['ngAnimate', 'ngCookies', 'ngResource', 'ngRoute', 'ngSanitize', 'ngTouch', 'ionic', 'ngTable', 'highcharts-ng', 'timer']).config(function($stateProvider, $urlRouterProvider, $httpProvider) {
    $stateProvider.state('app', {
        url: '/app',
        templateUrl: 'views/menu.html'
    }).state('app.main', {
        url: '/main',
        views: {
            'menuContent': {
                templateUrl: 'views/main.html',
                controller: 'analyticsController'
            }
        }
    }).state('app.cross', {
        url: '/cross/:cross',
        views: {
            'menuContent': {
                templateUrl: 'views/cross.html',
                controller: 'analyticsController'
            }
        }
    }).state('app.chart', {
        url: '/cross/:cross/chart',
        views: {
            'menuContent': {
                templateUrl: 'views/chart.html',
                controller: 'analyticsController'
            }
        }
    }).state('app.portfolio', {
        url: '/portfolio',
        views: {
            'menuContent': {
                templateUrl: 'views/portfolio.html',
                controller: 'portfolioController'
            }
        }
    }).state('app.about', {
        url: '/about',
        views: {
            'menuContent': {
                templateUrl: 'views/about.html'
            }
        }
    });
    $urlRouterProvider.otherwise('/app/main');
    // set interceptors
    $httpProvider.interceptors.push(function($q, $ionicLoading) {
        return {
            'request': function(config) {
                $ionicLoading.show({
                    template: 'Loading...'
                });
                return config;
            },
            'requestError': function(rejection) {
                $ionicLoading.hide();
                return $q.reject(rejection);
            },
            'response': function(response) {
                $ionicLoading.hide();
                return response;
            },
            'responseError': function(rejection) {
                $ionicLoading.hide();
                return $q.reject(rejection);
            }
        };
    });
    // hack for CORS
    $httpProvider.defaults.useXDomain = true;
    $httpProvider.defaults.headers.common = {
        'Connection': 'Keep-Alive',
        'Accept-Encoding': 'gzip, deflate'
    };
    $httpProvider.defaults.headers.post = {
        'Accept': 'application/json, text/plain, */*'
    };
    $httpProvider.defaults.headers.put = {
        'Content-Type': 'application/json'
    };
    $httpProvider.defaults.headers.patch = {};
});
var PhoneGapInit = function() {
    this.boot = function() {
        angular.bootstrap(document, ['aifxApp']);
    };
    if (window.phonegap !== undefined) {
        document.addEventListener('deviceready', function() {
            this.boot();
        });
        document.addEventListener('offline', function() {
            alert('Please check your internet connection');
        }, false);
    } else {
        this.boot();
    }
};
angular.element(document).ready(function() {
    new PhoneGapInit();
});