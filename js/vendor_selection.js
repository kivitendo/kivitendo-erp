function vendor_selection_window(input_name, input_id) {
  var parm = centerParms(600,500) + ",width=600,height=500,status=yes,scrollbars=yes";
  var name = document.getElementsByName(input_name)[0].value;
  url = "common.pl?" +
    "action=vendor_selection&" +
    "login=" + escape(document.getElementsByName("login")[0].value) + "&" +
    "password=" + escape(document.getElementsByName("password")[0].value) + "&" +
    "name=" + escape(name) + "&" +
    "input_name=" + escape(input_name) + "&" +
    "input_id=" + escape(input_id)
  //alert(url);
  window.open(url, "_new_generic", parm);
}
