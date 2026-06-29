function show_vc_details(vc) {
  var width = 750;
  var height = 550;
  var parm = centerParms(width, height) + ",width=" + width + ",height=" + height + ",status=yes,scrollbars=yes";
  var vc_id = document.getElementsByName(vc + "_id");
  if (vc_id)
    vc_id = vc_id[0].value;
  url = "common.pl?" +
    "INPUT_ENCODING=UTF-8&" +
    "action=show_vc_details&" +
    "vc=" + encodeURIComponent(vc) + "&" +
    "vc_id=" + encodeURIComponent(vc_id)
  //alert(url);
  window.open(url, "_new_generic", parm);
}
