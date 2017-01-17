namespace('kivi.AR', function(ns){
  'use strict';

  ns.check_fields_before_posting = function() {
    var errors = [];

    if ($('#transdate').val() === '')
      errors.push(kivi.t8('Invoice Date missing!'));

    if ($('#duedate').val() === '')
      errors.push(kivi.t8('Due Date missing!'));

    if ($('#customer').val() === '')
      errors.push(kivi.t8('Customer missing!'));

    if (errors.length === 0)
      return true;

    alert(errors.join(' '));

    return false;
  };
});
