function set_email_window(input_subject, input_body, input_attachment) {
  var parm = centerParms(800,600) + ",width=800,height=600,status=yes,scrollbars=yes";
  var url = "dn.pl?" +
    "INPUT_ENCODING=UTF-8&" +
    "action=set_email&" +
    "email_subject=" + encodeURIComponent(document.getElementsByName(input_subject)[0].value) + "&" +
    "email_body=" + encodeURIComponent(document.getElementsByName(input_body)[0].value) + "&" +
    "email_attachment=" + encodeURIComponent(document.getElementsByName(input_attachment)[0].value) + "&" +
    "input_subject=" + encodeURIComponent(input_subject)  + "&" +
    "input_body=" + encodeURIComponent(input_body)  + "&" +
    "input_attachment=" + encodeURIComponent(input_attachment);
  window.open(url, "_new_generic", parm);
}
