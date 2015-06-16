namespace('kivi.PaymentTerm', function(ns) {
  ns.auto_calculation_changed = function() {
    var $ctrl = $('#payment_term_terms_netto_as_number');

    if ($('#payment_term_auto_calculation').val() == 0)
      $ctrl.prop('disabled', true);
    else
      $ctrl.prop('disabled', false).focus();
  };
});

$(function() {
  $('#payment_term_auto_calculation').change(kivi.PaymentTerm.auto_calculation_changed);
});
