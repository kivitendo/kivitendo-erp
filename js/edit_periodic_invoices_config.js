function edit_periodic_invoices_config() {
  var width     = 750;
  var height    = 550;
  var parm      = centerParms(width, height) + ",width=" + width + ",height=" + height + ",status=yes,scrollbars=yes";

  var config    = $('#periodic_invoices_config').val();
  var transdate = $('#transdate').val();

  var url       = "oe.pl?" +
    "action=edit_periodic_invoices_config&" +
    "periodic_invoices_config=" + encodeURIComponent(config) + "&" +
    "transdate="                + encodeURIComponent(transdate);

  // alert(url);
  window.open(url, "_new_generic", parm);
}
