'use strict';
/**
 * @ngdoc service
 * @name platoApp.log
 * @description
 * # log
 * Service in the platoApp.
 */
angular.module('aifxApp').service('log', function utils($timeout) {
    var spinner = null;
    return {
        level: {
            notice: 1,
            success: 2,
            warning: 3,
            error: 4
        },
        current: null,
        clear: function() {
            this.current = null;
        },
        display: function(msg, level, timeout) {
            var _this = this;
            _this.current = {
                msg: msg,
                level: level
            };
            if (angular.isNumber(timeout)) {
                $timeout(function() {
                    _this.current = null;
                }, timeout);
            }
        },
        spinner: function(stop) {
            if (!stop && spinner === null) {
                var opts = {
                    lines: 11, // The number of lines to draw
                    length: 15, // The length of each line
                    width: 6, // The line thickness
                    radius: 17, // The radius of the inner circle
                    corners: 1, // Corner roundness (0..1)
                    rotate: 22, // The rotation offset
                    direction: 1, // 1: clockwise, -1: counterclockwise
                    color: '#000', // #rgb or #rrggbb or array of colors
                    speed: 0.7, // Rounds per second
                    trail: 76, // Afterglow percentage
                    shadow: true, // Whether to render a shadow
                    hwaccel: true, // Whether to use hardware acceleration
                    className: 'spinner', // The CSS class to assign to the spinner
                    zIndex: 2e9, // The z-index (defaults to 2000000000)
                    top: '50%', // Top position relative to parent
                    left: '50%' // Left position relative to parent
                };
                var target = document.querySelectorAll('body')[0];
                spinner = new Spinner(opts).spin(target);
            } else if (spinner !== null && stop) {
                spinner.stop();
                spinner = null;
            }
        }
    };
});
