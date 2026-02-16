function centerParms(width,height,extra) {
  xPos = (screen.width - width) / 2;
  yPos = (screen.height - height) / 2;

  string = "left=" + xPos + ",top=" + yPos;

  if (extra)
    string += "width=" + width + ",height=" + height;

  return string;
}

function set_history_window(id,trans_id_type, snumbers, what_done) {
  var parm = centerParms(1100,500) + ",width=1100,height=500,status=yes,scrollbars=yes";
  var url  = "common.pl?action=show_history&INPUT_ENCODING=UTF-8&";

  if (trans_id_type)
    url += "&trans_id_type=" + encodeURIComponent(trans_id_type);
  if (snumbers)
    url += "&s_numbers=" + encodeURIComponent(snumbers);
  if (what_done)
    url += "&what_done=" + encodeURIComponent(what_done);
  if (id)
    url += "&input_name=" + encodeURIComponent(id);

  window.open(url, "_new_generic", parm);
}
