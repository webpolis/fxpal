'use strict';
angular.module('aifxApp').directive('rateChange', function() {
    return {
        template: '<span></span>',
        restrict: 'E',
        link: function postLink(scope, element, attrs) {
            element.text('this is the rateChange directive');
        }
    };
});