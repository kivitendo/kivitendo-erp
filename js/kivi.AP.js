namespace('kivi.AP', function(ns){
  'use strict';

  ns.check_fields_before_posting = function() {
    var errors = [];

    if ($('#transdate').val() === '')
      errors.push(kivi.t8('Invoice Date missing!'));

    if ($('#duedate').val() === '')
      errors.push(kivi.t8('Due Date missing!'));

    if ($('#invnumber').val() === '')
      errors.push(kivi.t8('Invoice Number missing!'));

    if ($('#vendor').val() === '')
      errors.push(kivi.t8('Vendor missing!'));

    if (errors.length === 0)
      return true;

    alert(errors.join(' '));

    return false;
  };
});
