'use strict';
angular.module('aifxApp', ['ngAnimate', 'ngCookies', 'ngResource', 'ngRoute', 'ngSanitize', 'ngTouch', 'ionic', 'ngTable']).config(function($stateProvider, $urlRouterProvider) {
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
    } else {
        this.boot();
    }
};
angular.element(document).ready(function() {
    new PhoneGapInit();
});