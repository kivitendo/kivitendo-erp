namespace('kivi.PriceRuleMacro', function(ns) {
  "use strict";

  ns.reinit_widgets = function() {
    $('a.price_rule_macro_remove_line').click(function() {
      $(this).closest('.price_rule_element').remove();
    });
  };

  ns.add_new_element = function() {

  };

  ns.open_price_type_help_popup = function() {
    kivi.popup_dialog({
      url:    'controller.pl?action=PriceRule/price_type_help',
      dialog: { title: kivi.t8('Price Types') },
    });
  };

  $(function() {
    ns.reinit_widgets();

    $('#price_rule_item_add').click(function() {
      ns.add_new_row($('#price_rules_empty_item_select').val());
    });
    $('#price_rule_price_type_help').click(ns.open_price_type_help_popup);
  });
});
