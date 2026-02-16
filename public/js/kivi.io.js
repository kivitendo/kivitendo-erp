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

  ns.update_taxzone = function() {
    let expense_chart_ids = $('[name^="expense_chart_id_"]');
    expense_chart_ids.each(function (_idx, element) {
      element.value = null;
    });
    let tax_ids = $('[name^="tax_id_"]');
    tax_ids.each(function (_idx, element) {
      element.value = null;
    });
    let inventory_chart_ids = $('[name^="inventory_chart_id_"]');
    inventory_chart_ids.each(function (_idx, element) {
      element.value = null;
    });
    $('#update_button').click();
  }

  ns.update_tax_chart_picker = function(tax_chart_type, row_i) {
    $('#expense_chart_span_'   + row_i)[0].style.display = 'none';
    $('#inventory_chart_span_' + row_i)[0].style.display = 'none';

    let current_chart_picker_span = $('#' + tax_chart_type + '_chart_span_' + row_i)[0];
    current_chart_picker_span.style.display = 'inline';

    kivi.io.update_tax_ids($('#' + tax_chart_type + '_chart_id_' + row_i)[0]);
  }

  ns.update_tax_ids = function(obj) {
    var row = $(obj).attr('name').replace(/.*_/, '');

    $.ajax({
      url: 'io.pl?action=get_taxes_dropdown',
      data: { chart_id:          $(obj).val(),
              transdate:         $('#transdate').val(),
              deliverydate:      $('#deliverydate').val() },
              item_deliverydate: $("[name='reqdate_" + row + "']").val(), // has no id
      dataType: 'html',
      success: function (new_html) {
        $("#tax_id_" + row).html(new_html);
      }
    });
  };
});
