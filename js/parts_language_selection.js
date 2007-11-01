function parts_language_selection_window(input_name) {
  var parm = centerParms(600,500) + ",width=600,height=500,status=yes,scrollbars=yes";
  var name = document.getElementsByName(input_name)[0].value;
  url = "ic.pl?" +
    "action=parts_language_selection&" +
    "login="           + escape_more(document.ic.login.value)           + "&" +
    "password="        + escape_more(document.ic.password.value)        + "&" +
    "id="              + escape_more(document.ic.id.value)              + "&" +
    "language_values=" + escape_more(document.ic.language_values.value) + "&" +
    "name="            + escape_more(name)                              + "&" +
    "input_name="      + escape_more(input_name)                        + "&"
  window.open(url, "_new_generic", parm);
}
