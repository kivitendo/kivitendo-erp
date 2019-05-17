namespace('kivi.PriceRuleMacro', function(ns) {
  "use strict";

  ns.add_new_element = function() {
    $(this).uniqueId();

  };

  ns.add_value = function(e) {
    let elem = $(e.target);
    elem.uniqueId();

    $.post(
      'controller.pl',
      {
        action: 'PriceRuleMacro/add_value',
        type: elem.data('element-type'),
        prefix: elem.data('prefix'),
        container: elem.prop('id')
      },
      kivi.eval_json_result
    );
  };

  ns.add_element = function(e) {
    e.preventDefault();
    e.stopPropagation();

    let elem = $(e.target.closest('.add-element-control'));
    elem.uniqueId();

    $.post(
      'controller.pl',
      {
        action: 'PriceRuleMacro/add_element',
        type: elem.find('.element-type-select').val(),
        prefix: elem.data('prefix'),
        container: elem.prop('id')
      },
      kivi.eval_json_result
    );
  };

  ns.open_price_type_help_popup = function() {
    kivi.popup_dialog({
      url:    'controller.pl?action=PriceRule/price_type_help',
      dialog: { title: kivi.t8('Price Types') },
    });
  };


  ns.reinit_widgets = function() {
    kivi.run_once_for('span.price_rule_macro_remove_line', 'remove_line', function(elt) {
      $(elt).click(function() {
        $(this).closest('.price_rule_element').remove();
      });
    });
    kivi.run_once_for('span.price_rule_macro_add_value', 'add_value', function(elt) {
      $(elt).click(ns.add_value);
    });
    kivi.run_once_for('span.price_rule_macro_add_element', 'add_element', function(elt) {
      $(elt).click(ns.add_element);
    });
    $('span.price_rule_price_type_help').click(ns.open_price_type_help_popup);
  };

  $(function() {
    ns.reinit_widgets();
  });
});
