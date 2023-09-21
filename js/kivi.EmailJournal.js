namespace('kivi.EmailJournal', function(ns) {
  'use strict';

  ns.update_attachment_preview = function() {
    let $form = $('#record_action_form');
    if ($form == undefined) { return; }

    let data = $form.serializeArray();
    data.push({ name: 'action', value: 'EmailJournal/update_attachment_preview' });

    $.post("controller.pl", data, kivi.eval_json_result);
  }

  ns.update_extra_div_selection = function() {
    let record_action = $('#record_action').val();
    if (record_action == undefined) { return; }

    $('#customer_div').hide();
    $('#vendor_div').hide();

    $('#link_sales_quotation_div').hide();
    $('#link_sales_order_intake_div').hide();
    $('#link_sales_order_div').hide();
    $('#link_request_quotation_div').hide();
    $('#link_purchase_quotation_intake_div').hide();
    $('#link_purchase_order_div').hide();

    $('#placeholder_div').hide();

    // customer vendor
    if (record_action.match(/^customer/)) {
      $('#customer_div').show();
    } else if (record_action.match(/^vendor/)) {
      $('#vendor_div').show();
    // link
    } else if (record_action.match(/^link_/)) {
      $('#'+record_action+'_div').show();
    // placeholder
    } else {
      $('#placeholder_div').show();
    }
  }

  ns.apply_record_action = function() {
    let record_action = $('#record_action').val();
    if (record_action == '') {
      alert(kivi.t8('Please select an action.'));
      return;
    }

    let data = $('#record_action_form').serializeArray();
    data.push({ name: 'action', value: 'EmailJournal/apply_record_action' });

    $.post("controller.pl", data, kivi.eval_json_result);
  }
});

$(function() {
  kivi.EmailJournal.update_attachment_preview();
  kivi.EmailJournal.update_extra_div_selection();
});
