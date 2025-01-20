namespace('kivi.POS', function(ns) {
  ns.check_items = function() {

    if ($('.row_entry').length == 0) {
      alert(kivi.t8('Please add items first.'));
      return false;
    }

    return true;
  };

  ns.delete_order_item_row_point_of_sales = function(item_id) {
    var row = $('#item_' + item_id).parents("tbody").first();
    $(row).remove();

    $('#edit_order_item_row_dialog').dialog('close');
    kivi.Order.renumber_positions();
    kivi.Order.recalc_amounts_and_taxes();
  };


  ns.edit_order_item_row_point_of_sales = function(item_id) {

    var data = $('#order_form').serializeArray();
    data.push({ name: 'item_id', value: item_id });

    kivi.popup_dialog({
      url:    'controller.pl?action=POS/edit_order_item_row_dialog',
      data:   data,
      id:     'edit_order_item_row_dialog',
      load:   function() {kivi.reinit_widgets(); kivi.Order.init_row_handlers() },
      dialog: {
        title:  kivi.t8('Edit row'),
        width:  800,
        height: 650
      }
    });
  };

  ns.assign_edit_order_item_row_point_of_sales = function(item_id) {
    var row = $('#item_' + item_id).parents("tbody").first();

    var discount = $('#item_discount_as_percent').val();
    $(row).find('[name="discount_as_percent"]').html(discount);
    $(row).find('[name="order.orderitems[].discount_as_percent"]').val(discount);

    // TODO
    // var salesman_id = 0;
    // $(row).find('[name="order.orderitems[].salesman_id"]');


    $('#edit_order_item_row_dialog').dialog('close');
    kivi.Order.recalc_amounts_and_taxes();
  }

  ns.open_discount_item_dialog = function(type) {
    if (!kivi.Order.check_cv()) return;

    $("[name='discount.type']").val(type);

    kivi.popup_dialog({
      url:    'controller.pl?action=POS/add_discount_item_dialog',
      data:   {'discount.type': type},
      id:     'add_discount_item_dialog',
      load:   function() {
        kivi.reinit_widgets();
        kivi.Order.init_row_handlers()
        document.getElementById("discount_value_input").focus();
      },
      dialog: {
        title:  kivi.t8('Apply discount'),
        width:  300,
        height: 150
      }
    });

  }

  ns.apply_dicount_item_value = function() {
    var value_number = $("[name='discount.value_input']").val();

    var value = kivi.parse_amount(value_number);
    if (value != 0 && value != null) {
      $("[name='discount.value']").val(value_number);

      kivi.Order.add_discount_item();
    }
    $("#add_discount_item_dialog").dialog("close");
  }

  ns.submit = function(params) {
    if (!kivi.Order.check_cv()) return;
    if (!ns.check_items()) return;

    const action = params.action;

    var data = $('#order_form').serializeArray();
    data.push({ name: 'action', value: 'POS/' + action });

    $.post("controller.pl", data, kivi.eval_json_result);
  }

});
