function edit_periodic_invoices_config() {
  var width     = 800;
  var height    = 650;
  var parm      = centerParms(width, height) + ",width=" + width + ",height=" + height + ",status=yes,scrollbars=yes";

  var config    = $('#periodic_invoices_config').val();
  var cus_id    = $('[name=customer_id]').val();
  var transdate = $('#transdate').val();
  var lang_id   = $('#language_id').val();

  var url       = "oe.pl?" +
    "action=edit_periodic_invoices_config&" +
    "customer_id="              + encodeURIComponent(cus_id)  + "&" +
    "language_id="              + encodeURIComponent(lang_id) + "&" +
    "periodic_invoices_config=" + encodeURIComponent(config)  + "&" +
    "transdate="                + encodeURIComponent(transdate || '');

  // alert(url);
  window.open(url, "_new_generic", parm);
}
