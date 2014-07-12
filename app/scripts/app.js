'use strict';
angular.module('aifxApp', ['ngAnimate', 'ngCookies', 'ngResource', 'ngRoute', 'ngSanitize', 'ngTouch', 'ionic']).config(function($stateProvider, $urlRouterProvider) {
    $stateProvider.state('app', {
        url: '/app',
        templateUrl: 'views/menu.html',
        controller: 'appController'
    }).state('app.test', {
        url: '/test',
        views: {
            'menuContent': {
                templateUrl: 'views/test.html'
            }
        }
    });
    $urlRouterProvider.otherwise('/app');
});