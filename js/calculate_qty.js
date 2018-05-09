function calculate_qty_selection_window(input_name, input_id, formel_name, formel_id) {
  var parm = centerParms(600,500) + ",width=600,height=500,status=yes,scrollbars=yes";
  var action = "calculate_qty";
  if (formel_id) {
    var formel = $('#' + formel_id).val();
  } else {
    var formel = $('[name="' + formel_name + '"]').val();
  }
  url = "common.pl?" +
    "INPUT_ENCODING=UTF-8&" +
    "action=" + action + "&" +
    "input_name=" + encodeURIComponent(input_name) + "&" +
    "input_id="   + encodeURIComponent(input_id)   + "&" +
    "formel=" + encodeURIComponent(formel);
  //alert(url);
  window.open(url, "_new_generic", parm);
}
