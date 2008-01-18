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
      input_partnoes = "";
  }

  if (filter)
    filter = filter.value;
  else
    filter = "";

  if (!options)
    options = "";

  url = "common.pl?" +
    "action=part_selection_internal&" +
    "partnumber="              + escape_more(partnumber)        + "&" +
    "description="             + escape_more(description)       + "&" +
    "input_partnumber="        + escape_more(input_partnumber)  + "&" +
    "input_description="       + escape_more(input_description) + "&" +
    "input_partsid="           + escape_more(input_partsid)     + "&" +
    "input_partnotes="         + escape_more(input_partnotes)   + "&" +
    "filter="                  + escape_more(filter)            + "&" +
    "options="                 + escape_more(options)           + "&" +
    "allow_creation="          + (allow_creation ? "1" : "0")   + "&" +
    "action_on_part_selected=" + (null == action_on_part_selected ? "" : action_on_part_selected.value);
  //alert(url);
  window.open(url, "_new_part_selection", parm);
}

