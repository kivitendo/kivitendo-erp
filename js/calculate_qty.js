function calculate_qty_selection_window(input_name, formel) {
  var parm = centerParms(600,500) + ",width=600,height=500,status=yes,scrollbars=yes";
  var action = "calculate_qty";
  url = "common.pl?" +
    "INPUT_ENCODING=UTF-8&" +
    "action=" + action + "&" +
    "input_name=" + encodeURIComponent(input_name) + "&" +
   "formel=" + encodeURIComponent(document.getElementsByName(formel)[0].value)
  //alert(url);
  window.open(url, "_new_generic", parm);
}
