function customer_or_vendor_selection_window(input_name, input_id, is_vendor, allow_both, action_on_cov_selected) {
  var parm = centerParms(800,600) + ",width=800,height=600,status=yes,scrollbars=yes";
  var name = document.getElementsByName(input_name)[0].value;
  url = "common.pl?" +
    "INPUT_ENCODING=UTF-8&" +
    "action=cov_selection_internal&" +
    "name=" + encodeURIComponent(name) + "&" +
    "input_name=" + encodeURIComponent(input_name) + "&" +
    "input_id=" + encodeURIComponent(input_id) + "&" +
    "is_vendor=" + (is_vendor ? "1" : "0") + "&" +
    "allow_both=" + (allow_both ? "1" : "0") + "&" +
    "action_on_cov_selected=" + (action_on_cov_selected ? encodeURIComponent(action_on_cov_selected) : "")
  //alert(url);
  window.open(url, "_new_cov_selection", parm);
}
