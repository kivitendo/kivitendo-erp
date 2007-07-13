function set_email_window(input_subject, input_body, input_attachment) {
  var parm = centerParms(800,600) + ",width=800,height=600,status=yes,scrollbars=yes";
  var url = "dn.pl?" +
    "action=set_email&" +
    "login=" +  encodeURIComponent(document.getElementsByName("login")[0].value)+ "&"+
    "password=" + encodeURIComponent(document.getElementsByName("password")[0].value) + "&" +
    "email_subject=" + escape_more(document.getElementsByName(input_subject)[0].value) + "&" +
    "email_body=" + escape_more(document.getElementsByName(input_body)[0].value) + "&" +
    "email_attachment=" + escape_more(document.getElementsByName(input_attachment)[0].value) + "&" +
    "input_subject=" + escape_more(input_subject)  + "&" +
    "input_body=" + escape_more(input_body)  + "&" +
    "input_attachment=" + escape_more(input_attachment);
  window.open(url, "_new_generic", parm);
}
