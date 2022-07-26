namespace('kivi.PriceRule', function(ns) {
  "use strict";

  ns.add_new_row = function (type) {
    var data = {
      action: 'PriceRule/add_item_row',
      type: type
    };
    $.post('controller.pl', data, kivi.eval_json_result);
  };

  ns.open_price_type_help_popup = function() {
    kivi.popup_dialog({
      url:    'controller.pl?action=PriceRule/price_type_help',
      dialog: { title: kivi.t8('Price Types') },
    });
  };

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
    if (val === '') {
      $('#price_rule_filter_customer_tr').show();
      $('#price_rule_filter_vendor_tr').show();
    }
  };

  ns.inline_report = function(target, source, data){
    $.ajax({
      url:        source,
      success:    function (rsp) {
        $(target).html(rsp);
        $(target).find('.paginate').find('a').click(function(event){ ns.redirect_event(event, target) });
        $(target).find('a.report-generator-header-link').click(function(event){ ns.redirect_event(event, target) });
      },
      data:       data,
    });
  };
  ns.redirect_event = function(event, target){
    event.preventDefault();
    ns.inline_report(target, event.target + '', {});
  };

  ns.load_price_rules_for_part = function(id) {
    window.setTimeout(function(){
      ns.inline_report('#price_rules_customer_report', 'controller.pl', { action: 'PriceRule/list', 'filter.item_type_matches[].part': id, 'filter.type': 'customer', inline: 1 });
      ns.inline_report('#price_rules_vendor_report', 'controller.pl', { action: 'PriceRule/list', 'filter.item_type_matches[].part': id, 'filter.type': 'vendor', inline: 1 });
    }, 200);
  };

  $(function() {
    $('#price_rule_item_add').click(function() {
      ns.add_new_row($('#price_rules_empty_item_select').val());
    });
    $('#price_rule_items').on('click', 'a.price_rule_remove_line', function(){
      $(this).closest('.price_rule_item').remove();
    })
    $('#price_rule_price_type_help').click(ns.open_price_type_help_popup);
    $('#price_rule_filter_type').change(ns.on_change_filter_type);
  });

});
