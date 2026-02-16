namespace('kivi.Draft', function(ns) {
  'use strict';

  ns.popup = function(module, submodule, id, description) {
    $.get('controller.pl', {
      action: 'Draft/draft_dialog.js',
      module: module,
      submodule: submodule,
      id: id,
      description: description
    }, kivi.eval_json_result)
  }

  ns.save = function(module, submodule) {
    $.post('controller.pl', {
      action: 'Draft/save.js',
      module: module,
      submodule: submodule,
      form: $('form').serializeArray(),
      id: $('#new_draft_id').val(),
      description: $('#new_draft_description').val()
    }, kivi.eval_json_result)
  }

  ns.delete = function(id) {
    if (!confirm(kivi.t8('Do you really want to delete this draft?'))) return;

    $.post('controller.pl', {
      action: 'Draft/delete.js',
      id: id
    }, kivi.eval_json_result)

  }
});
