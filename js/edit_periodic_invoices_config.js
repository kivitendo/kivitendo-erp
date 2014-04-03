function edit_periodic_invoices_config() {
  var width     = 750;
  var height    = 550;
  var parm      = centerParms(width, height) + ",width=" + width + ",height=" + height + ",status=yes,scrollbars=yes";

  var config    = $('#periodic_invoices_config').val();
  var transdate = $('#transdate').val();

  var url       = "oe.pl?" +
    "action=edit_periodic_invoices_config&" +
    "periodic_invoices_config=" + encodeURIComponent(config) + "&" +
    "transdate="                + encodeURIComponent(transdate || '');

  // alert(url);
  window.open(url, "_new_generic", parm);
}

function warn_save_active_periodic_invoice() {
  return confirm(kivi.t8('This sales order has an active configuration for periodic invoices. If you save then all subsequently created invoices will contain those changes as well, but not those that have already been created. Do you want to continue?'));
}
