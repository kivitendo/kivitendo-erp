function parts_language_selection_window(input_name) {
  var parm = centerParms(600,500) + ",width=600,height=500,status=yes,scrollbars=yes";
  var name = document.getElementsByName(input_name)[0].value;
  url = "ic.pl?" +
    "INPUT_ENCODING=UTF-8&" +
    "action=parts_language_selection&" +
    "id="              + encodeURIComponent(document.ic.id.value)              + "&" +
    "language_values=" + encodeURIComponent(document.ic.language_values.value) + "&" +
    "name="            + encodeURIComponent(name)                              + "&" +
    "input_name="      + encodeURIComponent(input_name)                        + "&"
  window.open(url, "_new_generic", parm);
}
