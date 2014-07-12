'use strict';
angular.module('aifxApp', ['ngAnimate', 'ngCookies', 'ngResource', 'ngRoute', 'ngSanitize', 'ngTouch', 'ionic']).config(function($stateProvider, $urlRouterProvider) {
    $stateProvider.state('app', {
        url: '/app',
        templateUrl: 'views/menu.html'
    }).state('app.main', {
        url: '/main',
        views: {
            'menuContent': {
                templateUrl: 'views/main.html'
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