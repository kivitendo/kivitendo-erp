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

  ns.order_changed = function(value) {
    if (!value) {
      $('#time_recording_customer_id').data('customer_vendor_picker').set_item({});
      $('#time_recording_customer_id_name').prop('disabled', false);
      $('#time_recording_project_id').data('project_picker').set_item({});
      $('#time_recording_project_id_name').prop('disabled', false);
      return;
    }

    var url = 'controller.pl?action=TimeRecording/ajaj_get_order_info&id='+ value;
    $.getJSON(url, function(data) {
      $('#time_recording_customer_id').data('customer_vendor_picker').set_item(data.customer);
      $('#time_recording_customer_id_name').prop('disabled', true);
      $('#time_recording_project_id').data('project_picker').set_item(data.project);
      $('#time_recording_project_id_name').prop('disabled', true);
    });
  };

  ns.project_changed = function() {
    var project_id = $('#time_recording_project_id').val();

    if (!project_id) {
      $('#time_recording_customer_id_name').prop('disabled', false);
      return;
    }

    var url = 'controller.pl?action=TimeRecording/ajaj_get_project_info&id='+ project_id;
    $.getJSON(url, function(data) {
      if (data) {
        $('#time_recording_customer_id').data('customer_vendor_picker').set_item(data.customer);
        $('#time_recording_customer_id_name').prop('disabled', true);
      } else {
        $('#time_recording_customer_id_name').prop('disabled', false);
      }
    });
  };

});
