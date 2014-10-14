namespace('kivi.io', function(ns) {
  var $dialog;

  ns.price_chooser_dialog = function(title, html) {
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

  ns.close_dialog = function() {
    $dialog.dialog("close");
  }

  ns.price_chooser = function(i) {
    var form = $('form').serializeArray();
    form.push( { name: 'action', value: 'PriceSource/price_popup' }
             , { name: 'row',    value: i }
    );

    $.post('controller.pl', form, function(data) {
      kivi.eval_json_result(data);
    });
  }

  ns.update_price_source = function(row, source, price_str) {
    $('#active_price_source_' + row).val(source);
    if (price_str) $('#sellprice_' + row).val(price_str);
    $('#update_button').click();
  }

  ns.update_discount_source = function(row, source, discount_str) {
    $('#active_discount_source_' + row).val(source);
    if (discount_str) $('#discount_' + row).val(discount_str);
    $('#update_button').click();
  }
});
