namespace('kivi.VariantProperty', function(ns) {
  var $dialog;

  ns.variant_dialog = function(title, html) {
    var id            = 'jqueryui_popup_dialog';
    var dialog_params = {
      id:     id,
      width:  800,
      height: 500,
      modal:  true,
      close: function(event, ui) { $dialog.remove(); },
    };

    $('#' + id).remove();

    $dialog = $('<div style="display:none" id="' + id + '"></div>').appendTo('body');
    $dialog.attr('title', title);
    $dialog.html(html);
    $dialog.dialog(dialog_params);

    $('.cancel').click(ns.close_dialog);

    return true;
  };


  ns.save_variant_value = function() {
    var form = $('#variant_property_value_form').serializeArray();
    console.log("my", form)
    form.push( { name: 'action', value: 'VariantProperty/save_property_value' }
    );

    $.post('controller.pl', form, function(data) {
      kivi.eval_json_result(data);
    });
  };

  ns.add_or_edit_variant_value = function(id) {
    $.post('controller.pl', { action: 'VariantProperty/edit_property_value', id: id }, function(data) {
      kivi.eval_json_result(data);
    });
  };

});
