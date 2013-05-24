function part_selection_window(input_partnumber, input_description, input_partsid, allow_creation, formname, options) {
  var width                   = allow_creation ? 1000 : 800;
  var parm                    = centerParms(width,500) + ",width=" + width + ",height=500,status=yes,scrollbars=yes";
  var partnumber              = document.getElementsByName(input_partnumber)[0].value;
  var description             = document.getElementsByName(input_description)[0].value;
  var action_on_part_selected = document.getElementsByName("action_on_part_selected")[0];
  var form                    = (formname == undefined) ? document.forms[0] : document.getElementsByName(formname)[0];
  var filter                  = document.getElementsByName(input_partnumber + "_filter")[0];
  var input_partnotes         = "";

  if (input_partnumber.match(/_\d+$/)) {
    input_partnotes = input_partnumber;
    input_partnotes = input_partnotes.replace(/partnumber/, "partnotes");
    if (input_partnotes == input_partnumber)
      input_partnotes = "";
  }

  if (filter)
    filter = filter.value;
  else
    filter = "";

  if (!options)
    options = "";

  url = "common.pl?" +
    "INPUT_ENCODING=UTF-8&" +
    "action=part_selection_internal&" +
    "partnumber="              + encodeURIComponent(partnumber)        + "&" +
    "description="             + encodeURIComponent(description)       + "&" +
    "input_partnumber="        + encodeURIComponent(input_partnumber)  + "&" +
    "input_description="       + encodeURIComponent(input_description) + "&" +
    "input_partsid="           + encodeURIComponent(input_partsid)     + "&" +
    "input_partnotes="         + encodeURIComponent(input_partnotes)   + "&" +
    "filter="                  + encodeURIComponent(filter)            + "&" +
    "options="                 + encodeURIComponent(options)           + "&" +
    "formname="                + encodeURIComponent(formname)          + "&" +
    "allow_creation="          + (allow_creation ? "1" : "0")   + "&" +
    "action_on_part_selected=" + (null == action_on_part_selected ? "" : action_on_part_selected.value);
  //alert(url);
  window.open(url, "_new_part_selection", parm);
}

