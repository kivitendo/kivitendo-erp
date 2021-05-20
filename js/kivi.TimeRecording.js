namespace('kivi.TimeRecording', function(ns) {
  'use strict';

  ns.inputs_to_disable = [];

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

  var order_changed_called;
  ns.order_changed = function(value) {
    order_changed_called = true;

    if (!value) {
      $('#time_recording_customer_id').data('customer_vendor_picker').set_item({});
      $('#time_recording_customer_id_name').prop('disabled', false);
      $('#time_recording_project_id').data('project_picker').set_item({});
      $('#time_recording_project_id_name').prop('disabled', false);
      $('#time_recording_project_id ~ .ppp_popup_button').show()
      return;
    }

    var url = 'controller.pl?action=TimeRecording/ajaj_get_order_info&id='+ value;
    $.getJSON(url, function(data) {
      $('#time_recording_customer_id').data('customer_vendor_picker').set_item(data.customer);
      $('#time_recording_customer_id_name').prop('disabled', true);
      $('#time_recording_project_id').data('project_picker').set_item(data.project);
      $('#time_recording_project_id_name').prop('disabled', true);
      $('#time_recording_project_id ~ .ppp_popup_button').hide()
    });
  };

  ns.project_changed = function(event) {
    if (order_changed_called) {
      order_changed_called = false;
      return;
    }

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

  ns.set_input_constraints = function() {
    $(ns.inputs_to_disable).each(function(idx, elt) {
      if ("customer" === elt) {
        $('#time_recording_customer_id_name').prop('disabled', true);
      }
      if ("project" === elt) {
        $('#time_recording_project_id_name').prop('disabled', true);
        setTimeout(function() {$('#time_recording_project_id ~ .ppp_popup_button').hide();}, 100);
      }
    });
  };

  ns.assign_order_dialog = function(params) {
    var callback = params.callback;

    var data = $('#form').serializeArray();
    data     = data.concat($('#filter_form').serializeArray());
    data.push({name: 'action',   value: 'TimeRecording/assign_order_dialog'},
              {name: 'callback', value: callback});

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.assign_order = function() {
    var data = $('#form').serializeArray();
    data     = data.concat($('#assign_order_form').serializeArray());
    data.push({name: 'action',   value: 'TimeRecording/assign_order'});

    $('#assign_order_dialog').dialog('close');

    $.post("controller.pl", data, kivi.eval_json_result);
  };

});

$(function() {
  kivi.TimeRecording.set_input_constraints();
  $('#time_recording_project_id').on('set_item:ProjectPicker', function(){ kivi.TimeRecording.project_changed() });
});
