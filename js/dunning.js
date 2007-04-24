function set_email_window(input_subject, input_body, input_attachment) {
  var parm = centerParms(600,500) + ",width=600,height=500,status=yes,scrollbars=yes";
  var url = "dn.pl?" +
    "action=set_email&" +
    "login=" +  encodeURIComponent(document.getElementsByName("login")[0].value)+ "&"+
    "password=" + encodeURIComponent(document.getElementsByName("password")[0].value) + "&" +
    "email_subject=" + escape(document.getElementsByName(input_subject)[0].value) + "&" +
    "email_body=" + escape(document.getElementsByName(input_body)[0].value) + "&" +
    "email_attachment=" + escape(document.getElementsByName(input_attachment)[0].value) + "&" +
    "input_subject=" + escape(input_subject)  + "&" +
    "input_body=" + escape(input_body)  + "&" +
    "input_attachment=" + escape(input_attachment);
  window.open(url, "_new_generic", parm);
}
