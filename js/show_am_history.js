function set_history_uri() {
  document.location.href = "am.pl?" +
    "action=show_am_history&" +
    "longdescription=" + "&" +
    "einschraenkungen=" + document.getElementById("einschraenkungen").value + "&" +
    "fromdate=" + document.getElementById("fromdate_hidden").value + "&" +
    "todate=" + document.getElementById("todate_hidden").value + "&" +
    "what2search=" + document.getElementById("what2search").value + "&" +
    "searchid=" + document.getElementById("searchid").value + "&" +
    "mitarbeiter=" + document.getElementById("mitarbeiter_hidden").value + "&";
}
