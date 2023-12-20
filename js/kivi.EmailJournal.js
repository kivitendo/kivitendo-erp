namespace('kivi.EmailJournal', function(ns) {
  'use strict';

  ns.update_attachment_preview = function() {
    let $form = $('#record_action_form');

    let data = $form.serializeArray();
    data.push({ name: 'action', value: 'EmailJournal/update_attachment_preview' });

    $.post("controller.pl", data, kivi.eval_json_result);
  }

  ns.update_email_workflow_options = function() {
    let customer_vendor = $('#customer_vendor_selection').val();
    let record_action = $('#action_selection').val();

    // Hide all div
    ['customer', 'vendor'].forEach(function(cv) {
      $(`#${cv}_div`).hide();
      ['workflow_record', 'template_record', 'linking_record', 'new_record'].forEach(function(action) {
        $(`#${cv}_${action}_types_div`).hide();

      });
    });
    $('#new_record_div').hide();
    $('#template_record_div').hide();
    $('#record_selection_div').hide();

    // Enable needed div
    $(`#${customer_vendor}_div`).show();
    $(`#${customer_vendor}_${record_action}_types_div`).show();
    if (record_action == 'new_record') {
      $('#new_record_div').show();
      $('#new_record_div').css('display','inline-block')
    } else {
      $('#record_selection_div').show();
      kivi.EmailJournal.update_record_list();
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

  ns.zugferd_import_with_attachment = function(record_id, record_type) {
    let data = $('#record_action_form').serializeArray();
    data.push({ name: 'action', value: 'EmailJournal/zugferd_import_with_attachment' });
    data.push({ name: 'record_id', value: record_id });
    data.push({ name: 'record_type', value: record_type });

    $.post("controller.pl", data, kivi.eval_json_result);
  }

  ns.toggle_obsolete = function(email_journal_id) {
    let data = $('#record_action_form').serializeArray();
    data.push({ name: 'action', value: 'EmailJournal/toggle_obsolete' });
    data.push({ name: 'id', value: email_journal_id });

    $.post("controller.pl", data, kivi.eval_json_result);
  }
});
