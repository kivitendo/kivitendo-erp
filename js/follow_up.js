function follow_up_window() {
  var width = 900;
  var height = 700;
  var parm = centerParms(width, height) + ",width=" + width + ",height=" + height + ",status=yes,scrollbars=yes";

  url = "fu.pl?" +
    "INPUT_ENCODING=UTF-8&" +
    "action=add" + "&" +
    "POPUP_MODE=1";

  var trans_rowcount = document.getElementsByName("follow_up_rowcount");

  if (typeof trans_rowcount != "undefined") {
    for (i = 1; i <= trans_rowcount[0].value; i++) {
      var trans_id      = document.getElementsByName("follow_up_trans_id_" + i);
      var trans_type    = document.getElementsByName("follow_up_trans_type_" + i);
      var trans_info    = document.getElementsByName("follow_up_trans_info_" + i);
      var trans_subject = document.getElementsByName("follow_up_trans_subject_" + i);

      url += "&" +
        "trans_id_"      + i + "=" + encodeURIComponent(typeof trans_id      != "undefined" ? trans_id[0].value      : "") + "&" +
        "trans_type_"    + i + "=" + encodeURIComponent(typeof trans_type    != "undefined" ? trans_type[0].value    : "") + "&" +
        "trans_info_"    + i + "=" + encodeURIComponent(typeof trans_info    != "undefined" ? trans_info[0].value    : "") + "&" +
        "trans_subject_" + i + "=" + encodeURIComponent(typeof trans_subject != "undefined" ? trans_subject[0].value : "");
    }

    url += "&trans_rowcount=" + encodeURIComponent(trans_rowcount[0].value);
  }

  //alert(url);
  window.open(url, "_new_generic", parm);
}
