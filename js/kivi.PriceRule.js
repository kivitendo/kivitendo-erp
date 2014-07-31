namespace('kivi.PriceRule', function(ns) {

  ns.add_new_row = function (type) {
    var data = {
      action: 'PriceRule/add_item_row',
      type: type
    };
    $.post('controller.pl', data, kivi.eval_json_result);
  }

  $(function() {
    $('#price_rule_item_add').click(function() {
      ns.add_new_row($('#price_rules_empty_item_select').val());
    });
    $('#price_rule_items').on('click', 'a.price_rule_remove_line', function(){
      $(this).closest('div').remove();
    })
  });
});
