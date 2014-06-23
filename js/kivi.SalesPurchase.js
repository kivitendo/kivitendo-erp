namespace('kivi.SalesPurchase', function(ns) {
  this.edit_longdescription = function(row) {
    var $edit    = $('#popup_edit_longdescription_input');
    var $element = $('#longdescription_' + row);

    if (!$element.length) {
      console.error("kivi.SalesPurchase.edit_longdescription: Element #longdescription_" + row + " not found");
      return;
    }

    $edit.data('element', $element);
    $edit.val($element.val());

    $('#popup_edit_longdescription_runningnumber').html(row);
    $('#popup_edit_longdescription_partnumber').html($('#partnumber_' + row).val() || '');

    var description = ($('#description_' + row).val() || '').replace(/[\n\r]+/, '');
    if (description.length >= 50)
      description = description.substring(0, 50) + "…";
    $('#popup_edit_longdescription_description').html(description);

    kivi.popup_dialog({
      id:    'edit_longdescription_dialog',
      dialog: {
        title: kivi.t8('Enter longdescription'),
        open:  function() { kivi.set_focus('#popup_edit_longdescription_input'); }
      }
    });
  };

  this.set_longdescription = function() {
    var $edit    = $('#popup_edit_longdescription_input');
    var $element = $edit.data('element');

    $element.val($edit.val());
    $('#edit_longdescription_dialog').dialog('close');
  };

  this.delivery_order_check_transfer_qty = function() {
    var all_match = true;
    var rowcount  = $('input[name=rowcount]').val();
    for (var i = 1; i < rowcount; i++)
      if ($('#stock_in_out_qty_matches_' + i).val() != 1)
        all_match = false;

    if (all_match)
      return true;

    return confirm(kivi.t8('There are still transfers not matching the qty of the delivery order. Stock operations can not be changed later. Do you really want to proceed?'));
  };

  this.on_submit_checks = function() {
    var $button = $(this);
    if (($button.data('check-transfer-qty') == 1) && !kivi.SalesPurchase.delivery_order_check_transfer_qty())
      return false;

    return true;
  };

  this.init_on_submit_checks = function() {
     $('input[type=submit]').click(kivi.SalesPurchase.on_submit_checks);
  };
});
