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
angular.module('aifxApp', ['ngAnimate', 'ngCookies', 'ngResource', 'ngRoute', 'ngSanitize', 'ngTouch', 'ionic', 'ngTable', 'highcharts-ng']).config(function($stateProvider, $urlRouterProvider, $httpProvider) {
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
    });
    $urlRouterProvider.otherwise('/app/main');
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