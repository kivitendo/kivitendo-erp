namespace('kivi.Shop', function(ns) {

 ns.check_connectivity = function() {
   var dat = $('form').serializeArray();
    kivi.popup_dialog({
      url:    'controller.pl?action=Shop/check_connectivity',
      data:   dat,
      type:   'POST',
      id:     'test_shop_connection_window',
      dialog: { title: kivi.t8('Shop Connection Test') },
      width: 60,
      height: 40,
    });
    return true;
  };

});
