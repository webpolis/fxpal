'use strict';
angular.module('aifxApp').service('utils', function utils() {
    return {
        rfc3339: 'YYYY-MM-DDTHH:mm:ssZ',
        parseDate: function(dateString) {
            return moment(dateString).zone(moment().zone()).toDate();
        },
        formatDate: function(dateString, format) {
            format = format || this.rfc3339;
            return moment(dateString).zone(moment().zone()).format(format);
        },
        getRandomColorCode: function() {
            var letters = '0123456789ABCDEF'.split('');
            var color = '#';
            for (var i = 0; i < 6; i++) {
                color += letters[Math.floor(Math.random() * 16)];
            }
            return color;
        }
    };
});