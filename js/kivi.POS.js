namespace('kivi.POS', function(ns) {
  ns.check_items = function() {

    if ($('.row_entry').length == 0) {
      alert(kivi.t8('Please add items first.'));
      return false;
    }

    return true;
  };

  ns.delete_order_item_row_point_of_sale = function(item_id) {
    var row = $('#item_' + item_id).parents("tbody").first();
    $(row).remove();

    $('#edit_order_item_row_dialog').dialog('close');
    kivi.Order.renumber_positions();
    kivi.Order.recalc_amounts_and_taxes();
  };


  ns.edit_order_item_row_point_of_sale = function(item_id) {

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

  ns.assign_edit_order_item_row_point_of_sale = function(item_id) {
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

  ns.set_cash_customer = function() {
    var data = $('#order_form').serializeArray();
    data.push({ name: 'action', value: 'POS/set_cash_customer' });

    $.post("controller.pl", data, kivi.eval_json_result);
  }

  ns.set_cash_customer = function() {
    var data = $('#order_form').serializeArray();
    data.push({ name: 'action', value: 'POS/set_cash_customer' });

    $.post("controller.pl", data, kivi.eval_json_result);
  }

  ns.open_new_customer_dialog = function() {
    kivi.popup_dialog({
      url:    'controller.pl?action=POS/open_new_customer_dialog',
      id:     'new_customer_dialog',
      load:   function() {
        kivi.reinit_widgets();
        document.getElementById("new_customer_name").focus();
      },
      dialog: {
        title:  kivi.t8('New Customer'),
        width:  400,
        height: 300
      }
    });
  }

  ns.create_new_customer = function() {
    if (!kivi.Validator.validate_all('#new_customer_form')) return;

    var order_data = $('#order_form').serializeArray();
    var new_customer_data = $('#new_customer_form').serializeArray();
    var data = order_data.concat(new_customer_data);
    data.push({ name: 'action', value: 'POS/create_new_customer' });

    $.post("controller.pl", data, kivi.eval_json_result);
    $("#new_customer_dialog").dialog("close")
  }

  ns.submit = function(params) {
    if (!kivi.Order.check_cv()) return;
    if (!ns.check_items()) return;

    const action = params.action;

    var data = $('#order_form').serializeArray();
    data.push({ name: 'action', value: 'POS/' + action });

    $.post("controller.pl", data, kivi.eval_json_result);
  }

  ns.open_receipt_load_dialog = function() {
    kivi.popup_dialog({
      url:    'controller.pl?action=POS/open_receipt_load_dialog',
      id:     'receipt_load_dialog',
      load:   function() {
        kivi.reinit_widgets();
      },
      dialog: {
        title:  kivi.t8('Open stored receipts'),
        width:  800,
        height: 600
      }
    });
  }

  ns.open_order_informations_dialog = function() {
    document.getElementById('order_informations').showModal();
  }

  ns.open_payment_option_dialog = function() {
    if (!kivi.Order.check_cv()) return;
    if (!ns.check_items()) return;

    kivi.popup_dialog({
      id: 'payment_options_dialog',
      dialog: {
        title: kivi.t8('Payment options'),
        width:  400,
        height: 300
      }
    });

  }

  ns.open_payment_dialog = function(type) {
    // show amount to pay
    let amount = $('#amount_id').html() ;
    $('#payment_amount_id').html(amount);

    $('#payment_cash_value').val(null);
    $('#payment_terminal_value').val(null);
    if (type == 'cash') {
      $('#cash_value_row').show();
      $('#terminal_value_row').hide();
    } else if (type == 'terminal') {
      $('#payment_terminal_value').val(amount);
      $('#cash_value_row').hide();
      $('#terminal_value_row').show();
    } else if (type == 'cash_and_terminal') {
      $('#cash_value_row').show();
      $('#terminal_value_row').show();
    }

    $('#payment_options_dialog').dialog('close');
    kivi.popup_dialog({
      id: 'payment_dialog',
      load: function() { kivi.reinit_widgets(); },
      dialog: {
        title: kivi.t8('Payment'),
        width:  400,
        height: 300
      }
    });
  }

  ns.back_payment_dialog = function() {
    $('#payment_dialog').dialog('close');
    kivi.POS.open_payment_option_dialog();
  }

  ns.do_payment = function() {
    let cash_value = kivi.parse_amount($('#payment_cash_value').val());
    let terminal_value = kivi.parse_amount($('#payment_terminal_value').val());
    let amount_value = kivi.parse_amount($('#amount_id').html());

    if (cash_value + terminal_value < amount_value) {
      alert(kivi.t8("The amount entered is to small."));
      return
    }

    var data = $('#order_form').serializeArray();
    data.push({ name: 'action', value: 'POS/do_payment' },
              { name: 'payment.cash', value: cash_value },
              { name: 'payment.terminal', value: terminal_value });

    $.post("controller.pl", data, kivi.eval_json_result);
  }

  ns.open_paid_dialog = function(change) {
    $('#payment_dialog').dialog('close');

    if (change) {
      $('#paid_change_row').show();
      $('#paid_change_id').html(change)
    } else {
      $('#paid_change_row').hide();
    }

    kivi.popup_dialog({
      id: 'paid_dialog',
      dialog: {
        title: kivi.t8('Paid'),
        close: kivi.POS.open_new_order,
        width:  400,
        height: 300
      }
    });
  }

  ns.open_new_order = function() {
    let pos_id = $('#point_of_sale_id').val();
    console.log('pos_id', pos_id);
    window.location.replace(`controller.pl?action=POS/add&point_of_sale_id=${pos_id}`);
  }

});
