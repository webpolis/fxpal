'use strict';
angular.module('aifxApp').service('utils', function utils() {
    return {
        parseDate: function(dateString) {
            return moment(dateString).zone(moment().zone()).toDate();
        },
        formatDate: function(dateString, format) {
            format = format || 'YYYY-MM-DDTHH:mm:ssZ';
            return moment(dateString).zone(moment().zone()).format(format);
        }
    };
});