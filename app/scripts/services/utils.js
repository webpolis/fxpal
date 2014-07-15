'use strict';
angular.module('aifxApp').service('utils', function utils() {
    return {
        parseDate: function(dateString) {
            return moment(dateString).zone(moment().zone()).toDate();
        }
    };
});