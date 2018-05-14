function calculate_qty_selection_dialog(input_name, input_id, formel_name, formel_id) {
  // The target input element is determined by it's dom id or by it's name.
  // The formula input element (the one containing the formula) is determined by it's dom id or by it's name.
  // If the id is not provided the name is used.
  if (formel_id) {
    var formel = $('#' + formel_id).val();
  } else {
    var formel = $('[name="' + formel_name + '"]').val();
  }
  var url  = "common.pl";
  var data = {
    action:     "calculate_qty",
    input_name: input_name,
    input_id:   input_id,
    formel:     formel
  };
  kivi.popup_dialog({
    id:     'calc_qty_dialog',
    url:    url,
    data:   data,
    dialog: {
      width:  500,
      height: 400,
      title:  kivi.t8('Please enter values'),
    }
  });
}
