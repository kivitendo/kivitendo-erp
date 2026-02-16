namespace('kivi.Dunning', function(ns) {
  "use strict";

  ns.enable_disable_language_id = function() {
    $('select[name="language_id"]').prop('disabled', !$('#force_lang').prop('checked'));
  };

  $(function() {
    $('#force_lang').click(kivi.Dunning.enable_disable_language_id);
    kivi.Dunning.enable_disable_language_id();
  });
});
