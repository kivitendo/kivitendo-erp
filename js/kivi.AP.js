namespace('kivi.AP', function(ns){
  'use strict';

  ns.check_fields_before_posting = function() {
    var errors = [];

    // if the element transdate exists, we have a AP form otherwise we have to check the invoice form
    var invoice_date = ($('#transdate').length === 0) ? $('#transdate').val() : $('#invdate').val();
    if (invoice_date === '')
      errors.push(kivi.t8('Invoice Date missing!'));

    if ($('#duedate').val() === '')
      errors.push(kivi.t8('Due Date missing!'));

    if ($('#invnumber').val() === '')
      errors.push(kivi.t8('Invoice Number missing!'));

    if ($('#vendor_id').val() ===  '')
      errors.push(kivi.t8('Vendor missing!'));

    if (errors.length === 0)
      return true;

    alert(errors.join(' '));

    return false;
  };

  ns.check_duplicate_invnumber = function() {
    var exists_invnumber = false;

    $.ajax({
      url: 'controller.pl',
      data: { action: 'SalesPurchase/check_duplicate_invnumber',
              vendor_id    : $('#vendor_id').val(),
              invnumber    : $('#invnumber').val()
      },
      method: "GET",
      async: false,
      dataType: 'text',
      success: function(val) {
        exists_invnumber = val;
      }
    });

    if (exists_invnumber == 1) {
      return confirm(kivi.t8('This vendor has already a booking with this invoice number, do you really want to add the same invoice number again?'));
    }

    return true;
  };

});
