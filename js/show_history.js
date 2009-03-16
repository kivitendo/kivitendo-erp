function centerParms(width,height,extra) {
  xPos = (screen.width - width) / 2;
  yPos = (screen.height - height) / 2;

  string = "left=" + xPos + ",top=" + yPos;

  if (extra)
    string += "width=" + width + ",height=" + height;

  return string;
}

function set_history_window(id) {
  var parm = centerParms(800,500) + ",width=800,height=500,status=yes,scrollbars=yes";
  var name = "History";
  url = "common.pl?" +
    "INPUT_ENCODING=UTF-8&" +
    "action=show_history&" +
    "longdescription=" + "&" +
    "input_name=" + encodeURIComponent(id) + "&"
  window.open(url, "_new_generic", parm);
}
