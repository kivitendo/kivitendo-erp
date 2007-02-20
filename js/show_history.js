function centerParms(width,height,extra) {
  xPos = (screen.width - width) / 2;
  yPos = (screen.height - height) / 2;

  string = "left=" + xPos + ",top=" + yPos;

  if (extra)
    string += "width=" + width + ",height=" + height;

  return string;
}

function set_history_window(id) {
  var parm = centerParms(600,500) + ",width=600,height=500,status=yes,scrollbars=yes";
  var name = "History";
  url = "common.pl?" +
    "action=show_history&" +
    "login=" +  encodeURIComponent(document.getElementsByName("login")[0].value)+ "&"+
    "password=" + encodeURIComponent(document.getElementsByName("password")[0].value) + "&" +
    "path=" + encodeURIComponent(document.getElementsByName("path")[0].value) + "&" +
    "longdescription=" + "&" +
    "input_name=" + escape(id) + "&"
  window.open(url, "_new_generic", parm);
}