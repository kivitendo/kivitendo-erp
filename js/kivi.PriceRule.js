namespace('kivi.PriceRule', function(ns) {

  ns.add_new_row = function (type) {
    var data = {
      action: 'PriceRule/add_item_row',
      type: type
    };
    $.post('controller.pl', data, kivi.eval_json_result);
  }

  ns.open_price_type_help_popup = function() {
    kivi.popup_dialog({
      url:    'controller.pl?action=PriceRule/price_type_help',
      dialog: { title: kivi.t8('Price Types') },
    });
  }

  ns.on_change_filter_type = function() {
    var val = $('#price_rule_filter_type').val();
    if (val == 'vendor') {
      $('#price_rule_filter_customer').data('customer_vendor_picker').set_item({});
      $('#price_rule_filter_customer_tr').hide();
      $('#price_rule_filter_vendor_tr').show();
    }
    if (val == 'customer') {
      $('#price_rule_filter_vendor').data('customer_vendor_picker').set_item({});
      $('#price_rule_filter_vendor_tr').hide();
      $('#price_rule_filter_customer_tr').show();
    }
    if (val == '') {
      $('#price_rule_filter_customer_tr').show();
      $('#price_rule_filter_vendor_tr').show();
    }
  }

  $(function() {
    $('#price_rule_item_add').click(function() {
      ns.add_new_row($('#price_rules_empty_item_select').val());
    });
    $('#price_rule_items').on('click', 'a.price_rule_remove_line', function(){
      $(this).closest('div').remove();
    })
    $('#price_rule_price_type_help').click(ns.open_price_type_help_popup);
    $('#price_rule_filter_type').change(ns.on_change_filter_type);
  });
});
