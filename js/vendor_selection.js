function vendor_selection_window(input_name, input_id) {
  var parm = centerParms(600,500) + ",width=600,height=500,status=yes,scrollbars=yes";
  var name = document.getElementsByName(input_name)[0].value;
  url = "common.pl?" +
    "INPUT_ENCODING=UTF-8&" +
    "action=vendor_selection&" +
    "name=" + encodeURIComponent(name) + "&" +
    "input_name=" + encodeURIComponent(input_name) + "&" +
    "input_id=" + encodeURIComponent(input_id)
  //alert(url);
  window.open(url, "_new_generic", parm);
}
