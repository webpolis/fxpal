'use strict';

describe('Directive: rateChange', function () {

  // load the directive's module
  beforeEach(module('aifxApp'));

  var element,
    scope;

  beforeEach(inject(function ($rootScope) {
    scope = $rootScope.$new();
  }));

  it('should make hidden element visible', inject(function ($compile) {
    element = angular.element('<rate-change></rate-change>');
    element = $compile(element)(scope);
    expect(element.text()).toBe('this is the rateChange directive');
  }));
});
