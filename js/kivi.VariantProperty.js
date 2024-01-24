namespace('kivi.VariantProperty', function(ns) {
  var $dialog;

  ns.variant_property_value_dialog = function(title, html) {
    var id = 'jqueryui_popup_dialog';
    var dialog_params = {
      id:     id,
      width:  800,
      height: 500,
      modal:  true,
      close: function(_event, _ui) { $dialog.remove(); },
    };

    $('#' + id).remove();

    $dialog = $('<div style="display:none" id="' + id + '"></div>').appendTo('body');
    $dialog.attr('title', title);
    $dialog.html(html);
    $dialog.dialog(dialog_params);

    $('.cancel').click(ns.close_dialog);

    return true;
  };

  ns.save_variant_property_value = function() {
    var data = $('#variant_property_value_form').serializeArray();
    data.push({ name: 'action', value: 'VariantProperty/save_variant_property_value' });
    $.post('controller.pl', data, kivi.eval_json_result);
  };

  ns.add_variant_property_value = function() {
    var data = $('#variant_property_value_list_form').serializeArray();
    data.push({ name: 'action', value: 'VariantProperty/add_variant_property_value' });
    $.post("controller.pl", data, kivi.eval_json_result);
  }

  ns.edit_variant_property_value = function(variant_property_value_id) {
    $.post('controller.pl', {
      action: 'VariantProperty/edit_variant_property_value',
      variant_property_value_id: variant_property_value_id
    }, kivi.eval_json_result);
  };

});
