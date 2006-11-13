function centerParms(width,height,extra) {
  xPos = (screen.width - width) / 2;
  yPos = (screen.height - height) / 2;

  string = "left=" + xPos + ",top=" + yPos;

  if (extra)
    string += "width=" + width + ",height=" + height;

  return string;
}

function set_longdescription_window(input_name) {
  var parm = centerParms(600,500) + ",width=600,height=500,status=yes,scrollbars=yes";
  var name = document.getElementsByName(input_name)[0].value;
  url = "common.pl?" +
    "action=set_longdescription&" +
    "login=" +  encodeURIComponent(document.getElementsByName("login")[0].value)+ "&"+
    "password=" + encodeURIComponent(document.getElementsByName("password")[0].value) + "&" +
    "path=" + encodeURIComponent(document.getElementsByName("path")[0].value) + "&" +
    "longdescription=" + escape(document.getElementsByName(input_name)[0].value) + "&" +
    "input_name=" + escape(input_name) + "&"
  window.open(url, "_new_generic", parm);
}
