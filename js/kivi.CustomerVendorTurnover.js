namespace('kivi.CustomerVendorTurnover', function(ns) {

  ns.show_dun_stat = function(period) {
    if (period === 'y') {
      var url = 'controller.pl?action=CustomerVendorTurnover/count_open_items_by_year&id=' + $('#cv_id').val();
      $('#duns').load(url);
    } else {
      var url = 'controller.pl?action=CustomerVendorTurnover/count_open_items_by_month&id=' + $('#cv_id').val();
      $('#duns').load(url);
    }
  };

  ns.get_invoices = function() {
    var url = 'controller.pl?action=CustomerVendorTurnover/get_invoices&id=' + $('#cv_id').val() + '&db=' + $('#db').val();
    $('#invoices').load(url);
  };

  ns.get_sales_quotations = function() {
    var url = 'controller.pl?action=CustomerVendorTurnover/get_orders&id=' + $('#cv_id').val() + '&db=' + $('#db').val() + '&type=quotation';
    $('#quotations').load(url);
  };

  ns.get_orders = function() {
    var url = 'controller.pl?action=CustomerVendorTurnover/get_orders&id=' + $('#cv_id').val() + '&db=' + $('#db').val() + '&type=order';
    $('#orders').load(url);
  };

  ns.get_letters = function() {
    var url = 'controller.pl?action=CustomerVendorTurnover/get_letters&id=' + $('#cv_id').val() + '&db=' + $('#db').val();;
    $('#letters').load(url);
  };

  ns.get_mails = function() {
    var url = 'controller.pl?action=CustomerVendorTurnover/get_mails&id=' + $('#cv_id').val() + '&db=' + $('#db').val();;
    $('#mails').load(url);
  };

  ns.show_turnover_stat = function(period) {
    if (period === 'y') {
      var url = 'controller.pl?action=CustomerVendorTurnover/turnover_by_year&id=' + $('#cv_id').val() + '&db=' + $('#db').val();
      $('#turnovers').load(url);
    } else {
      var url = 'controller.pl?action=CustomerVendorTurnover/turnover_by_month&id=' + $('#cv_id').val() + '&db=' + $('#db').val();
      $('#turnovers').load(url);
    }
  };

});
