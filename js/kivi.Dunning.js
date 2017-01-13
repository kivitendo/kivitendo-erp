namespace('kivi.Dunning', function(ns) {
  ns.check_invoice_selection = function() {
    if ($('[name^=active_]:checked').length > 0)
      return true;

    alert(kivi.t8('No invoices have been selected.'));
    return false;
  };

  ns.enable_disable_language_id = function() {
    $('select[name="language_id"]').prop('disabled', !$('#force_lang').prop('checked'));
  };

  $(function() {
    $('#force_lang').click(kivi.Dunning.enable_disable_language_id);
    kivi.Dunning.enable_disable_language_id();
  });
});
