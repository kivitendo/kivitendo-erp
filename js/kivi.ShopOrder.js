namespace('kivi.ShopOrder', function(ns) {
  ns.massTransferInitialize = function() {
    kivi.popup_dialog({
      id: 'status_mass_transfer',
      dialog: {
        title: kivi.t8('Status Shoptransfer'),
      }
    });
  };

  ns.massTransferStarted = function() {
    $('#status_mass_transfer').data('timerId', setInterval(function() {
      $.get("controller.pl", {
        action: 'ShopOrder/transfer_status',
        job_id: $('#smt_job_id').val()
      }, kivi.eval_json_result);
    }, 5000));
  };

  ns.massTransferFinished = function() {
    clearInterval($('#status_mass_transfer').data('timerId'));
    $('.ui-dialog-titlebar button.ui-dialog-titlebar-close').prop('disabled', '')
  };

  ns.processClose = function() {
    $('#status_mass_transfer').dialog('close');
    window.location.href = 'controller.pl?filter.obsolete=0&filter.transferred=0&action=ShopOrder%2flist&db=shop_orders&sort_by=shop_ordernumber';
  };

  ns.setup = function() {
    kivi.ShopOrder.massTransferInitialize();
    kivi.submit_ajax_form('controller.pl?action=ShopOrder/mass_transfer','[name=shop_orders_list]');
  };

});
