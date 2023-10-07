namespace('kivi.EmailJournal', function(ns) {
  'use strict';

  ns.update_attachment_preview = function() {
    let $form = $('#record_action_form');
    if ($form == undefined) { return; }

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
    kivi.EmailJournal.update_record_type_selection(customer_vendor);
  }

  ns.update_action_selection = function() {
    let record_action = $('#action_selection').val();

    $('#record_type_div').hide();
    $('#no_record_type_div').hide();

    if (record_action == 'create_new') {
      $('#no_record_type_div').show();
    } else {
      $('#record_type_div').show();
    }
  }

  ns.update_record_type_selection = function(customer_vendor) {
    let record_type = $('#' + customer_vendor + '_record_type_selection').val();

    $('.record_type').hide();
    if (record_type != '') {
      $('#' + record_type + '_div').show();
    } else {
      $('#record_type_placeholder_div').show();
    }
  }

  ns.apply_action_with_attachment = function() {
    let data = $('#record_action_form').serializeArray();
    data.push({ name: 'action', value: 'EmailJournal/apply_record_action' });

    $.post("controller.pl", data, kivi.eval_json_result);
  }
});

$(function() {
  kivi.EmailJournal.update_attachment_preview();
});
