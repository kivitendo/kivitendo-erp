namespace('kivi.PriceRuleMacro', function(ns) {
  "use strict";

  ns.add_new_element = function() {
    $(this).uniqueId();

  };

  ns.add_line = function(e) {
    let elem = $(e.target);
    elem.uniqueId();

    $.post(
      'controller.pl',
      {
        action: 'PriceRuleMacro/add_line',
        type: elem.data('element-type'),
        prefix: elem.data('prefix'),
        container: elem.prop('id')
      },
      kivi.eval_json_result
    );
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
        element_class: elem.data('element-class'),
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

  ns.list_template_price_toggle = function() {
    let $this    = $(this);
    let field    = $this.data('field');
    let $element = $this.closest('.price_rule_element');
    $element.find('input.hidden-' + field).prop('disabled', function(i,v){ return !v; });
    $element.find('span.input-' + field).toggle();
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
    kivi.run_once_for('span.price_rule_macro_add_line', 'add_line', function(elt) {
      $(elt).click(ns.add_line);
    });
    kivi.run_once_for('span.price_rule_macro_add_element', 'add_element', function(elt) {
      $(elt).click(ns.add_element);
    });
    kivi.run_once_for('span.list-template-price-toggle', 'price_toggle', function(elt) {
      $(elt).click(ns.list_template_price_toggle);
    });
    $('span.price_rule_price_type_help').click(ns.open_price_type_help_popup);
  };

  $(function() {
    ns.reinit_widgets();
  });
});
