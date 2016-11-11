namespace('kivi.DeliveryOrder', function(ns) {
  ns.multi_invoice_check_delivery_orders_selected = function() {
    if ($('#orders_form tbody input[type=checkbox]:checked').length > 0)
      return true;

    alert(kivi.t8('You have not selected any delivery order.'));

    return false;
  };
});
