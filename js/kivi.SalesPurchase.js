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
        title: kivi.t8('Enter longdescription')
      }
    });
  };

  this.set_longdescription = function() {
    var $edit    = $('#popup_edit_longdescription_input');
    var $element = $edit.data('element');

    $element.val($edit.val());
    $('#edit_longdescription_dialog').dialog('close');
  };
});
