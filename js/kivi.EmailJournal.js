namespace('kivi.EmailJournal', function(ns) {
  'use strict';

  ns.update_attachment_preview = function() {
    let $form = $('#record_action_form');

    let data = $form.serializeArray();
    data.push({ name: 'action', value: 'EmailJournal/update_attachment_preview' });

    $.post("controller.pl", data, kivi.eval_json_result);
  }

  ns.update_customer_vendor_selection = function() {
    let customer_vendor = $('#customer_vendor_selection').val();

    $('#customer_div').hide();
    $('#customer_record_types_div').hide();
    $('#vendor_div').hide();
    $('#vendor_record_types_div').hide();

    if (customer_vendor == 'customer') {
      $('#customer_div').show();
      $('#customer_record_types_div').show();
    } else { // if (customer_vendor == 'vendor')
      $('#vendor_div').show();
      $('#vendor_record_types_div').show();
    }
    kivi.EmailJournal.update_record_list();
  }

  ns.update_action_selection = function() {
    let record_action = $('#action_selection').val();

    $('#record_selection_div').hide();
    $('#create_new_div').hide();

    if (record_action == 'create_new') {
      $('#create_new_div').show();
      $('#create_new_div').css('display','inline-block')
    } else {
      $('#record_selection_div').show();
    }
  }

  ns.update_record_list = function() {
    let $form = $('#record_action_form');

    let data = $form.serializeArray();
    data.push({ name: 'action', value: 'EmailJournal/update_record_list' });

    $.post("controller.pl", data, kivi.eval_json_result);
  }

  ns.apply_action_with_attachment = function(record_id, record_type) {
    let data = $('#record_action_form').serializeArray();
    data.push({ name: 'action', value: 'EmailJournal/apply_record_action' });
    data.push({ name: 'record_id', value: record_id });
    data.push({ name: 'record_type', value: record_type });

    $.post("controller.pl", data, kivi.eval_json_result);
  }
});
