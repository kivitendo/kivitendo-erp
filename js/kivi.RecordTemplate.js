namespace('kivi.RecordTemplate', function(ns) {
  'use strict';

  ns.popup = function(template_type) {
    $.get('controller.pl', {
      action:        'RecordTemplate/show_dialog.js',
      template_type: template_type,
    }, kivi.eval_json_result);
  };

  ns.create = function() {
    var new_name = $("#record_template_dialog_new_template_name").val();
    if (new_name === '') {
      alert(kivi.t8('Error: Name missing'));
      return false;
    }

    kivi.RecordTemplate.save(undefined, new_name);
  };

  ns.save = function(id, name) {
    var $type = $("#record_template_dialog_template_type");
    var $form = $($type.data('form_selector'));

    if (!$form) {
      console.log("nothing found for form_selector " + $type.data("form_selector"));
      return false;
    }

    if ((id !== undefined) && !confirm(kivi.t8('Are you sure you want to update the selected record template with the current values? This cannot be undone.')))
      return false;

    var data = $form.serializeArray().filter(function(val) { return val.name !== 'action'; });
    data.push({ name: 'action',                            value: $type.data('save_action') });
    data.push({ name: 'record_template_id',                value: id });
    data.push({ name: 'record_template_new_template_name', value: name });

    $.post($type.data('controller'), data, kivi.eval_json_result);
  };

  ns.load = function(id) {
    var $type = $("#record_template_dialog_template_type");
    var url   = encodeURIComponent($type.data('controller'))
              + '?action=' + encodeURIComponent($type.data('load_action'))
              + '&id='     + encodeURIComponent(id);

    console.log(url);

    window.location = url;
  };

  ns.rename = function(id) {
    var current_name = $("#record_template_dialog_template_name_" + id).val();
    var new_name     = prompt(kivi.t8("Please enter the new name:"), current_name);

    if ((new_name === current_name) || !new_name || (new_name === ''))
      return;

    $.post('controller.pl', {
      action: 'RecordTemplate/rename.js',
      id: id,
      template_name: new_name
    }, kivi.eval_json_result);
  };

  ns.delete = function(id) {
    if (!confirm(kivi.t8('Do you really want to delete this record template?')))
      return;

    $.post('controller.pl', {
      action: 'RecordTemplate/delete.js',
      id: id
    }, kivi.eval_json_result);
  };

  ns.filter_templates = function() {
    $.post('controller.pl', {
      action: 'RecordTemplate/filter_templates',
      template_filter: $("#template_filter").val(),
      template_type: $("#record_template_dialog_template_type").val(),
    }, kivi.eval_json_result);
  };
});
