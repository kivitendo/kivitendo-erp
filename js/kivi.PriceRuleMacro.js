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
        "parent.action_type": elem.data('action_type'),
        "parent.condition_type": elem.data('condition_type'),
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

  ns.replace_element = function(e) {
    let $e = $(e.target);
    e.preventDefault();
    e.stopPropagation();

    let elem = $(e.target.closest('.price_rule_element'));
    elem.uniqueId();

    $.post(
      'controller.pl',
      {
        action: 'PriceRuleMacro/replace_element',
        type: $e.data('element-type'),
        prefix: $e.data('prefix'),
        "params.condition_type": $e.data('condition-type'),
        element_class: $e.data('element-class'),
        container: elem.prop('id')
      },
      kivi.eval_json_result
    );
  };

  ns.add_empty_block = function(e) {
    e.preventDefault();
    e.stopPropagation();

    let elem = $(e.target.closest('.add-element-control'));
    elem.uniqueId();

    $.post(
      'controller.pl',
      {
        action: 'PriceRuleMacro/add_element',
        type: elem.data('element-class'),
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

  ns.remove_element_event = function(elt) {
    ns.remove_element($(this).closest('.price_rule_element'));
  };

  ns.remove_element = function($element) {
    let parent_element = $element.parents('.price_rule_element').get(0);

    if (parent_element === undefined) {
      //$element.find('.price_rule_macro_add_empty_block').click();
      let $last_elem = $element.find('.price_rule_macro_add_empty_block');
      $last_elem.uniqueId();

      $.post(
        'controller.pl',
        {
          action: 'PriceRuleMacro/add_element',
          type: 'conditional_action',
          prefix: $last_elem.data('prefix'),
          element_class: 'action',
          container: $last_elem.prop('id')
        },
        kivi.eval_json_result
      );
      return;
    }

    $element.remove();

    // if this was the last elemet in this subtree, remove the parent element too
    if ($(parent_element).find('.price_rule_element').length === 0) {
      ns.remove_element($(parent_element));
    }
  };

  ns.simple_action_input_price_type_changed = function(e) {
    let $input = $(e.target);
    let price_type = $input.val();
    let $content = $input.parent('div.simple_action_input_content');
    $content.children('.simple_action_input_price').hide();
    $content.children('.simple_action_input_reduction').hide();
    $content.children('.simple_action_input_discount').hide();

    if (price_type === '0') {
      $content.children('.simple_action_input_price').show();
    }
    if (price_type === '1') {
      $content.children('.simple_action_input_reduction').show();
    }
    if (price_type === '2') {
      $content.children('.simple_action_input_discount').show();
    }
  };

  ns.reinit_widgets = function() {
    kivi.run_once_for('span.price_rule_macro_remove_line', 'remove_line', function(elt) {
      $(elt).click(ns.remove_element_event);
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
    kivi.run_once_for('.price_rule_macro_replace_element', 'replace_element', function(elt) {
      $(elt).click(ns.replace_element);
    });
    kivi.run_once_for('fieldset.price_rule_macro_add_empty_block', 'add_empty_block', function(elt) {
      $(elt).click(ns.add_empty_block);
    });
    kivi.run_once_for('span.list-template-price-toggle', 'price_toggle', function(elt) {
      $(elt).click(ns.list_template_price_toggle);
    });
    kivi.run_once_for('select.simple_action_input_price_type', 'price_type_changed', function(elt) {
      $(elt).change(ns.simple_action_input_price_type_changed);
    });
    $('span.price_rule_price_type_help').click(ns.open_price_type_help_popup);
  };

  $(function() {
    ns.reinit_widgets();
  });
});
