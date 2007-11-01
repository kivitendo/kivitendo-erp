function customer_or_vendor_selection_window(input_name, input_id, is_vendor, allow_both, action_on_cov_selected) {
  var parm = centerParms(800,600) + ",width=800,height=600,status=yes,scrollbars=yes";
  var name = document.getElementsByName(input_name)[0].value;
  url = "common.pl?" +
    "action=cov_selection_internal&" +
    "login=" + escape(document.forms[0].login.value) + "&" +
    "password=" + escape(document.forms[0].password.value) + "&" +
    "name=" + escape_more(name) + "&" +
    "input_name=" + escape(input_name) + "&" +
    "input_id=" + escape(input_id) + "&" +
    "is_vendor=" + (is_vendor ? "1" : "0") + "&" +
    "allow_both=" + (allow_both ? "1" : "0") + "&" +
    "action_on_cov_selected=" + (action_on_cov_selected ? escape(action_on_cov_selected) : "")
  //alert(url);
  window.open(url, "_new_cov_selection", parm);
}
