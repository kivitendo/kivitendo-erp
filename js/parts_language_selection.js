function parts_language_selection_window(input_name) {
  var parm = centerParms(600,500) + ",width=600,height=500,status=yes,scrollbars=yes";
  var name = document.getElementsByName(input_name)[0].value;
  url = "ic.pl?" +
    "action=parts_language_selection&" +
    "login=" + escape(document.ic.login.value) + "&" +
    "password=" + escape(document.ic.password.value) + "&" +
    "id=" + escape(document.ic.id.value) + "&" +
    "language_values=" + escape(document.ic.language_values.value) + "&" +
    "name=" + escape(name) + "&" +
    "input_name=" + escape(input_name) + "&"
  window.open(url, "_new_generic", parm);
}
