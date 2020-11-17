namespace('kivi.TimeRecording', function(ns) {
  'use strict';

  ns.set_end_date = function() {
    if ($('#start_date').val() !== '' && $('#end_date').val() === '') {
      var kivi_start_date  = kivi.format_date(kivi.parse_date($('#start_date').val()));
      $('#end_date').val(kivi_start_date);
    }
  };

  ns.set_current_date_time = function(what) {
    if (what !== 'start' && what !== 'end') return;

    var $date = $('#' + what + '_date');
    var $time = $('#' + what + '_time');
    var date = new Date();

    $date.val(kivi.format_date(date));
    $time.val(kivi.format_time(date));
  };

});
