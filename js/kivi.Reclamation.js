namespace('kivi.Reclamation', function(ns) {
  ns.check_cv = function() {
    if ($('#type').val() == 'sales_reclamation') {
      if ($('#reclamation_customer_id').val() === '') {
        alert(kivi.t8('Please select a customer.'));
        return false;
      }
    } else  {
      if ($('#reclamation_vendor_id').val() === '') {
        alert(kivi.t8('Please select a vendor.'));
        return false;
      }
    }
    return true;
  };

  ns.check_duplicate_parts = function(question) {
    var id_arr = $('[name="reclamation.reclamation_items[].parts_id"]').map(function() { return this.value; }).get();

    var i, obj = {}, pos = [];

    for (i = 0; i < id_arr.length; i++) {
      var id = id_arr[i];
      if (obj.hasOwnProperty(id)) {
        pos.push(i + 1);
      }
      obj[id] = 0;
    }

    if (pos.length > 0) {
      question = question || kivi.t8("Do you really want to continue?");
      return confirm(kivi.t8("There are duplicate parts at positions") + "\n"
                     + pos.join(', ') + "\n"
                     + question);
    }
    return true;
  };

  ns.check_valid_reqdate = function() {
    if ($('#reclamation_reqdate_as_date').val() === '') {
      alert(kivi.t8('Please select a deadline date.'));
      return false;
    } else {
      return true;
    }
  };

  ns.check_valid_reasons = function() {
    var positions_with_empty = [];

    $('.row_entry').each(function(idx, elt) {
      if ($(elt).find('[name="reclamation.reclamation_items[].reason_id"]').val() == '') {
        positions_with_empty.push(idx+1);
      }
    });

    if (positions_with_empty.length > 0) {
      alert(kivi.t8("There are parts with no reclamation reason at position:") + "\n"
            + positions_with_empty.join(', ') );
      return false;
    } else {
      return true;
    }
  };

  ns.save = function(params) {
    if (!ns.check_cv()) return;

    const action             = params.action;
    const warn_on_duplicates = params.warn_on_duplicates;
    const warn_on_reqdate    = params.warn_on_reqdate;
    const form_params        = params.form_params;

    if (warn_on_duplicates && !ns.check_duplicate_parts()) return;
    if (warn_on_reqdate    && !ns.check_valid_reqdate())   return;
    if (!ns.check_valid_reasons())                     return;

    var data = $('#reclamation_form').serializeArray();
    data.push({ name: 'action', value: 'Reclamation/' + action });
    if (form_params) {
      if (Array.isArray(form_params)) {
        form_params.forEach(function(item) {
          data.push(item);
        });
      } else {
        data.push(form_params);
      }
    }

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.delete_reclamation = function() {
    var data = $('#reclamation_form').serializeArray();
    data.push({ name: 'action', value: 'Reclamation/delete' });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.show_print_options = function(warn_on_duplicates, warn_on_reqdate) {
    if (!ns.check_cv()) return;
    if (warn_on_duplicates && !ns.check_duplicate_parts(kivi.t8("Do you really want to print?"))) return;
    if (warn_on_reqdate    && !ns.check_valid_reqdate())   return;

    kivi.popup_dialog({
      id: 'print_options',
      dialog: {
        title: kivi.t8('Print options'),
        width:  800,
        height: 300
      }
    });
  };

  ns.print = function() {
    $('#print_options').dialog('close');

    var data = $('#reclamation_form').serializeArray();
    data = data.concat($('#print_options_form').serializeArray());
    data.push({ name: 'action', value: 'Reclamation/print' });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  var email_dialog;

  ns.setup_send_email_dialog = function() {
    kivi.SalesPurchase.show_all_print_options_elements();
    kivi.SalesPurchase.show_print_options_elements([ 'sendmode', 'media', 'copies', 'remove_draft' ], false);

    $('#print_options_form table').first().remove().appendTo('#email_form_print_options');

    var to_focus = $('#email_form_to').val() === '' ? 'to' : 'subject';
    $('#email_form_' + to_focus).focus();
  };

  ns.finish_send_email_dialog = function() {
    kivi.SalesPurchase.show_all_print_options_elements();

    $('#email_form_print_options table').first().remove().prependTo('#print_options_form');
    return true;
  };

  ns.show_email_dialog = function(html) {
    var id            = 'send_email_dialog';
    var dialog_params = {
      id:     id,
      width:  800,
      height: 600,
      title:  kivi.t8('Send email'),
      modal:  true,
      beforeClose: kivi.Reclamation.finish_send_email_dialog,
      close: function(event, ui) {
        email_dialog.remove();
      }
    };

    $('#' + id).remove();

    email_dialog = $('<div style="display:none" id="' + id + '"></div>').appendTo('body');
    email_dialog.html(html);
    email_dialog.dialog(dialog_params);

    kivi.Reclamation.setup_send_email_dialog();

    $('.cancel').click(ns.close_email_dialog);

    return true;
  };

  ns.send_email = function() {
    // push button only once -> slow response from mail server
    ns.email_dialog_disable_send();

    var data = $('#reclamation_form').serializeArray();
    data = data.concat($('[name^="email_form."]').serializeArray());
    data = data.concat($('[name^="print_options."]').serializeArray());
    data.push({ name: 'action', value: 'Reclamation/send_email' });
    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.email_dialog_disable_send = function() {
    // disable mail send event to prevent
    // impatient users to send multiple times
    $('#send_email').prop('disabled', true);
  };

  ns.close_email_dialog = function() {
    email_dialog.dialog("close");
  };

  ns.set_number_in_title = function(elt) {
    $('#nr_in_title').html($(elt).val());
  };

  ns.reload_cv_dependent_selections = function() {
    $('#reclamation_shipto_id').val('');
    var data = $('#reclamation_form').serializeArray();
    data.push({ name: 'action', value: 'Reclamation/customer_vendor_changed' });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.reformat_number = function(event) {
    $(event.target).val(kivi.format_amount(kivi.parse_amount($(event.target).val()), -2));
  };

  ns.reformat_number_as_null_number = function(event) {
    if ($(event.target).val() === '') {
      return;
    }
    ns.reformat_number(event);
  };

  ns.update_exchangerate = function(event) {
    if (!ns.check_cv()) {
      $('#reclamation_currency_id').val($('#old_currency_id').val());
      return;
    }

    var rate_input = $('#reclamation_exchangerate_as_null_number');
    // unset exchangerate if currency changed
    if ($('#reclamation_currency_id').val() !== $('#old_currency_id').val()) {
      rate_input.val('');
    }

    // only set exchangerate if unset
    if (rate_input.val() !== '') {
      return;
    }

    var data = $('#reclamation_form').serializeArray();
    data.push({ name: 'action', value: 'Reclamation/update_exchangerate' });

    $.ajax({
      url: 'controller.pl',
      data: data,
      method: 'POST',
      dataType: 'json',
      success: function(data){
        if (!data.is_standard) {
          $('#currency_name').text(data.currency_name);
          if (data.exchangerate) {
            rate_input.val(data.exchangerate);
          } else {
            rate_input.val('');
          }
          $('#reclamation_exchangerate_as_null_number').data('validate', 'required');
          $('#exchangerate_settings').show();
        } else {
          rate_input.val('');
          $('#reclamation_exchangerate_as_null_number').data('validate', '');
          $('#exchangerate_settings').hide();
        }
        if ($('#reclamation_currency_id').val() != $('#old_currency_id').val() ||
            !data.is_standard && data.exchangerate != $('#old_exchangerate').val()) {
          kivi.display_flash('warning', kivi.t8('You have changed the currency or exchange rate. Please check prices.'));
        }
        $('#old_currency_id').val($('#reclamation_currency_id').val());
        $('#old_exchangerate').val(data.exchangerate);
      }
    });
  };

  ns.exchangerate_changed = function(event) {
    if (kivi.parse_amount($('#reclamation_exchangerate_as_null_number').val()) != kivi.parse_amount($('#old_exchangerate').val())) {
      kivi.display_flash('warning', kivi.t8('You have changed the currency or exchange rate. Please check prices.'));
      $('#old_exchangerate').val($('#reclamation_exchangerate_as_null_number').val());
    }
  };

  ns.recalc_amounts_and_taxes = function() {
    var data = $('#reclamation_form').serializeArray();
    data.push({ name: 'action', value: 'Reclamation/recalc_amounts_and_taxes' });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.unit_change = function(event) {
    var row           = $(event.target).parents("tbody").first();
    var item_id_dom   = $(row).find('[name="reclamation_item_ids[+]"]');
    var sellprice_dom = $(row).find('[name="reclamation.reclamation_items[].sellprice_as_number"]');
    var select_elt    = $(row).find('[name="reclamation.reclamation_items[].unit"]');

    var oldval = $(select_elt).data('oldval');
    $(select_elt).data('oldval', $(select_elt).val());

    var data = $('#reclamation_form').serializeArray();
    data.push({ name: 'action',           value: 'Reclamation/unit_changed'     },
              { name: 'item_id',          value: item_id_dom.val()        },
              { name: 'old_unit',         value: oldval                   },
              { name: 'sellprice_dom_id', value: sellprice_dom.attr('id') });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.update_sellprice = function(item_id, price_str) {
    var row       = $('#item_' + item_id).parents("tbody").first();
    var price_elt = $(row).find('[name="reclamation.reclamation_items[].sellprice_as_number"]');
    var html_elt  = $(row).find('[name="sellprice_text"]');
    price_elt.val(price_str);
    html_elt.html(price_str);
  };

  ns.load_second_row = function(row) {
    var item_id_dom = $(row).find('[name="reclamation_item_ids[+]"]');
    var div_elt     = $(row).find('[name="second_row"]');

    if ($(div_elt).data('loaded') == 1) {
      return;
    }
    var data = $('#reclamation_form').serializeArray();
    data.push({ name: 'action',     value: 'Reclamation/load_second_rows' },
              { name: 'item_ids[]', value: item_id_dom.val()        });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.load_all_second_rows = function() {
    var rows = $('.row_entry').filter(function(idx, elt) {
      return $(elt).find('[name="second_row"]').data('loaded') != 1;
    });

    var item_ids = $.map(rows, function(elt) {
      var item_id = $(elt).find('[name="reclamation_item_ids[+]"]').val();
      return { name: 'item_ids[]', value: item_id };
    });

    if (item_ids.length == 0) {
      return;
    }

    var data = $('#reclamation_form').serializeArray();
    data.push({ name: 'action', value: 'Reclamation/load_second_rows' });
    data = data.concat(item_ids);

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.hide_second_row = function(row) {
    $(row).children().not(':first').hide();
    $(row).data('expanded', 0);
    var elt = $(row).find('.expand');
    elt.attr('src', "image/expand.svg");
    elt.attr('alt', kivi.t8('Show details'));
    elt.attr('title', kivi.t8('Show details'));
  };

  ns.show_second_row = function(row) {
    $(row).children().not(':first').show();
    $(row).data('expanded', 1);
    var elt = $(row).find('.expand');
    elt.attr('src', "image/collapse.svg");
    elt.attr('alt', kivi.t8('Hide details'));
    elt.attr('title', kivi.t8('Hide details'));
  };

  ns.toggle_second_row = function(row) {
    if ($(row).data('expanded') == 1) {
      ns.hide_second_row(row);
    } else {
      ns.show_second_row(row);
    }
  };

  ns.init_row_handlers = function() {
    kivi.run_once_for('.recalc', 'on_change_recalc', function(elt) {
      $(elt).change(ns.recalc_amounts_and_taxes);
    });

    kivi.run_once_for('.reformat_number', 'on_change_reformat', function(elt) {
      $(elt).change(ns.reformat_number);
    });

    kivi.run_once_for('.unitselect', 'on_change_unit_with_oldval', function(elt) {
      $(elt).data('oldval', $(elt).val());
      $(elt).change(ns.unit_change);
    });

    kivi.run_once_for('.row_entry', 'on_kbd_click_show_hide', function(elt) {
      $(elt).keydown(function(event) {
        var row;
        if (event.keyCode == 40 && event.shiftKey === true) {
          // shift arrow down
          event.preventDefault();
          row = $(event.target).parents(".row_entry").first();
          ns.load_second_row(row);
          ns.show_second_row(row);
          return false;
        }
        if (event.keyCode == 38 && event.shiftKey === true) {
          // shift arrow up
          event.preventDefault();
          row = $(event.target).parents(".row_entry").first();
          ns.hide_second_row(row);
          return false;
        }
      });
    });

    kivi.run_once_for('.expand', 'expand_second_row', function(elt) {
      $(elt).click(function(event) {
        event.preventDefault();
        var row = $(event.target).parents(".row_entry").first();
        ns.load_second_row(row);
        ns.toggle_second_row(row);
        return false;
      })
    });

  };

  ns.redisplay_line_values = function(is_sales, data) {
    $('.row_entry').each(function(idx, elt) {
      $(elt).find('[name="linetotal"]').html(data[idx][0]);
      if (is_sales && $(elt).find('[name="second_row"]').data('loaded') == 1) {
        var mt = data[idx][1];
        var mp = data[idx][2];
        var h  = '<span';
        if (mt[0] === '-') h += ' class="plus0"';
        h += '>' + mt + '&nbsp;&nbsp;' + mp + '%';
        h += '</span>';
        $(elt).find('[name="linemargin"]').html(h);
      }
    });
  };

  ns.redisplay_cvpartnumbers = function(data) {
    $('.row_entry').each(function(idx, elt) {
      $(elt).find('[name="cvpartnumber"]').html(data[idx][0]);
    });
  };

  ns.renumber_positions = function() {
    $('.row_entry [name="position"]').each(function(idx, elt) {
      $(elt).html(idx+1);
    });
    $('.row_entry').each(function(idx, elt) {
      $(elt).data("position", idx+1);
    });
  };

  ns.reorder_items = function(order_by) {
    var dir = $('#' + order_by + '_header_id a img').attr("data-sort-dir");
    $('#row_table_id thead a img').remove();

    var src;
    if (dir == "1") {
      dir = "0";
      src = "image/up.png";
    } else {
      dir = "1";
      src = "image/down.png";
    }

    $('#' + order_by + '_header_id a').append('<img border=0 data-sort-dir=' + dir + ' src=' + src + ' alt="' + kivi.t8('sort items') + '">');

    var data = $('#reclamation_form').serializeArray();
    data.push({ name: 'action',   value: 'Reclamation/reorder_items' },
              { name: 'order_by', value: order_by              },
              { name: 'sort_dir', value: dir                   });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.redisplay_items = function(data) {
    var old_rows = $('.row_entry').detach();
    var new_rows = [];
    $(data).each(function(idx, elt) {
      new_rows.push(old_rows[elt.old_pos - 1]);
    });
    $(new_rows).appendTo($('#row_table_id'));
    ns.renumber_positions();
  };

  ns.get_insert_before_item_id = function(wanted_pos) {
    if (wanted_pos === '') return;

    var insert_before_item_id;
    // selection by data does not seem to work if data is changed at runtime
    // var elt = $('.row_entry [data-position="' + wanted_pos + '"]');
    $('.row_entry').each(function(idx, elt) {
      if ($(elt).data("position") == wanted_pos) {
        insert_before_item_id = $(elt).find('[name="reclamation_item_ids[+]"]').val();
        return false;
      }
    });

    return insert_before_item_id;
  };

  ns.update_item_input_row = function() {
    if (!ns.check_cv()) return;

    var data = $('#reclamation_form').serializeArray();
    data.push({ name: 'action', value: 'Reclamation/update_item_input_row' });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.add_item = function() {
    if ($('#add_item_parts_id').val() === '') return;
    if (!ns.check_cv()) return;

    $('#row_table_id thead a img').remove();

    var insert_before_item_id = ns.get_insert_before_item_id($('#add_item_position').val());

    var data = $('#reclamation_form').serializeArray();
    data.push({ name: 'action', value: 'Reclamation/add_item' },
              { name: 'insert_before_item_id', value: insert_before_item_id });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.open_multi_items_dialog = function() {
    if (!ns.check_cv()) return;

    var pp = $("#add_item_parts_id").data("part_picker");
    pp.o.multiple=1;
    pp.open_dialog();
  };

  ns.add_multi_items = function(data) {
    var insert_before_item_id = ns.get_insert_before_item_id($('#multi_items_position').val());
    data = data.concat($('#reclamation_form').serializeArray());
    data.push({ name: 'action', value: 'Reclamation/add_multi_items' },
              { name: 'insert_before_item_id', value: insert_before_item_id });
    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.delete_reclamation_item_row = function(clicked) {
    var row = $(clicked).parents("tbody").first();
    $(row).remove();

    ns.renumber_positions();
    ns.recalc_amounts_and_taxes();
  };

  ns.row_table_scroll_down = function() {
    $('#row_table_scroll_id').scrollTop($('#row_table_scroll_id')[0].scrollHeight);
  };

  ns.show_longdescription_dialog = function(clicked) {
    var row                 = $(clicked).parents("tbody").first();
    var position            = $(row).find('[name="position"]').html();
    var partnumber          = $(row).find('[name="partnumber"]').html();
    var description_elt     = $(row).find('[name="reclamation.reclamation_items[].description"]');
    var longdescription_elt = $(row).find('[name="reclamation.reclamation_items[].longdescription"]');

    var params = {
      runningnumber:           position,
      partnumber:              partnumber,
      description:             description_elt.val(),
      default_longdescription: longdescription_elt.val(),
      set_function:            function(val) {
        longdescription_elt.val(val);
      }
    };

    kivi.SalesPurchase.edit_longdescription_with_params(params);
  };

  ns.price_chooser_item_row = function(clicked) {
    if (!ns.check_cv()) return;
    var row         = $(clicked).parents("tbody").first();
    var item_id_dom = $(row).find('[name="reclamation_item_ids[+]"]');

    var data = $('#reclamation_form').serializeArray();
    data.push({ name: 'action',  value: 'Reclamation/price_popup' },
              { name: 'item_id', value: item_id_dom.val()   });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.set_price_and_source_text = function(item_id, source, descr, price_str, price_editable) {
    var row        = $('#item_' + item_id).parents("tbody").first();
    var source_elt = $(row).find('[name="reclamation.reclamation_items[].active_price_source"]');
    var button_elt = $(row).find('[name="price_chooser_button"]');

    button_elt.val(button_elt.val().replace(/.*\|/, descr + " |"));
    source_elt.val(source);

    var editable_div_elt     = $(row).find('[name="editable_price"]');
    var not_editable_div_elt = $(row).find('[name="not_editable_price"]');
    if (price_editable == 1 && source === '') {
      // editable
      $(editable_div_elt).show();
      $(not_editable_div_elt).hide();
      $(editable_div_elt).find(':input').prop("disabled", false);
      $(not_editable_div_elt).find(':input').prop("disabled", true);
    } else {
      // not editable
      $(editable_div_elt).hide();
      $(not_editable_div_elt).show();
      $(editable_div_elt).find(':input').prop("disabled", true);
      $(not_editable_div_elt).find(':input').prop("disabled", false);
    }

    if (price_str) {
      var price_elt = $(row).find('[name="reclamation.reclamation_items[].sellprice_as_number"]');
      var html_elt  = $(row).find('[name="sellprice_text"]');
      price_elt.val(price_str);
      html_elt.html(price_str);
    }
  };

  ns.update_price_source = function(item_id, source, descr, price_str, price_editable) {
    ns.set_price_and_source_text(item_id, source, descr, price_str, price_editable);

    if (price_str) ns.recalc_amounts_and_taxes();
    kivi.io.close_dialog();
  };

  ns.set_discount_and_source_text = function(item_id, source, descr, discount_str, price_editable) {
    var row        = $('#item_' + item_id).parents("tbody").first();
    var source_elt = $(row).find('[name="reclamation.reclamation_items[].active_discount_source"]');
    var button_elt = $(row).find('[name="price_chooser_button"]');

    button_elt.val(button_elt.val().replace(/\|.*/, "| " + descr));
    source_elt.val(source);

    var editable_div_elt     = $(row).find('[name="editable_discount"]');
    var not_editable_div_elt = $(row).find('[name="not_editable_discount"]');
    if (price_editable == 1 && source === '') {
      // editable
      $(editable_div_elt).show();
      $(not_editable_div_elt).hide();
      $(editable_div_elt).find(':input').prop("disabled", false);
      $(not_editable_div_elt).find(':input').prop("disabled", true);
    } else {
      // not editable
      $(editable_div_elt).hide();
      $(not_editable_div_elt).show();
      $(editable_div_elt).find(':input').prop("disabled", true);
      $(not_editable_div_elt).find(':input').prop("disabled", false);
    }

    if (discount_str) {
      var discount_elt = $(row).find('[name="reclamation.reclamation_items[].discount_as_percent"]');
      var html_elt     = $(row).find('[name="discount_text"]');
      discount_elt.val(discount_str);
      html_elt.html(discount_str);
    }
  };

  ns.update_discount_source = function(item_id, source, descr, discount_str, price_editable) {
    ns.set_discount_and_source_text(item_id, source, descr, discount_str, price_editable);

    if (discount_str) ns.recalc_amounts_and_taxes();
    kivi.io.close_dialog();
  };

  ns.update_row_from_master_data = function(clicked) {
    var row = $(clicked).parents("tbody").first();
    var item_id_dom = $(row).find('[name="reclamation_item_ids[+]"]');

    var data = $('#reclamation_form').serializeArray();
    data.push({ name: 'action', value: 'Reclamation/update_row_from_master_data' });
    data.push({ name: 'item_ids[]', value: item_id_dom.val() });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.update_all_rows_from_master_data = function() {
    var item_ids = $.map($('.row_entry'), function(elt) {
      var item_id = $(elt).find('[name="reclamation_item_ids[+]"]').val();
      return { name: 'item_ids[]', value: item_id };
    });

    if (item_ids.length == 0) {
      return;
    }

    var data = $('#reclamation_form').serializeArray();
    data.push({ name: 'action', value: 'Reclamation/update_row_from_master_data' });
    data = data.concat(item_ids);

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.show_calculate_qty_dialog = function(clicked) {
    var row        = $(clicked).parents("tbody").first();
    var input_id   = $(row).find('[name="reclamation.reclamation_items[].qty_as_number"]').attr('id');
    var formula_id = $(row).find('[name="formula[+]"]').attr('id');

    calculate_qty_selection_dialog("", input_id, "", formula_id);
    return true;
  };

  ns.edit_custom_shipto = function() {
    if (!ns.check_cv()) return;

    kivi.SalesPurchase.edit_custom_shipto();
  };

  ns.purchase_reclamation_check_for_direct_delivery = function(save_params) {
    if ($('#type').val() != 'sales_reclamation') {
      return alert(kivi.t8("Error: This is not a sales reclamation."));
    }

    var empty = true;
    var shipto;
    if ($('#reclamation_shipto_id').val() !== '') {
      empty = false;
      shipto = $('#reclamation_shipto_id option:selected').text();
    } else {
      $('#shipto_inputs [id^="shipto"]').each(function(_idx, elt) {
        if (!empty)                                     return;
        if (/^shipto_to_copy/.test($(elt).prop('id')))  return;
        if (/^shiptocp_gender/.test($(elt).prop('id'))) return;
        if (/^shiptocvar_/.test($(elt).prop('id')))     return;
        if ($(elt).val() !== '') {
          empty = false;
          return;
        }
      });
      var shipto_elements = [];
      $([$('#shiptoname').val(), $('#shiptostreet').val(), $('#shiptozipcode').val(), $('#shiptocity').val()]).each(function(_idx, elt) {
        if (elt !== '') shipto_elements.push(elt);
      });
      shipto = shipto_elements.join('; ');
    }

    if (!empty) {
      ns.direct_delivery_dialog(shipto, save_params);
    } else {
      ns.save(save_params);
    }
  };

  ns.direct_delivery_callback = function(accepted, save_params) {
    $('#direct-delivery-dialog').dialog('close');

    if (accepted) {
      $('<input type="hidden" name="use_shipto">').appendTo('#reclamation_form').val('1');
    }

    ns.save(save_params);
  };

  ns.direct_delivery_dialog = function(shipto, save_params) {
    $('#direct-delivery-dialog').remove();

    var save_params_string = '{';
    if (save_params) {
      const action             = save_params.action;
      const warn_on_duplicates = save_params.warn_on_duplicates;
      const warn_on_reqdate    = save_params.warn_on_reqdate;
      const form_params        = save_params.form_params;


      console.log(form_params)
      console.log(Array.isArray(form_params))
      if (action)
        save_params_string += `'action':'${action}',`;
      if (warn_on_duplicates)
        save_params_string += `'warn_on_duplicates':'${warn_on_duplicates}',`;
      if (warn_on_reqdate)
        save_params_string += `'warn_on_reqdate':'${warn_on_reqdate}',`;
      if (Array.isArray(form_params)) {
        save_params_string += 'form_params:['
        form_params.forEach(function(item) {
          save_params_string += `{'name':'${item.name}','value':'${item.value}'},`;
        });
        save_params_string += ']';
      } else {
        save_params_string += `'form_params':{'name':'${form_params.name}','value':'${form_params.value}'}`;
      }
    }
    save_params_string += '}';

    console.log(save_params_string);

    var text1 = kivi.t8('You have entered or selected the following shipping address for this customer:');
    var text2 = kivi.t8('Do you want to carry this shipping address over to the new purchase reclamation so that the vendor can deliver the goods directly to your customer?');
    var html  = '<div id="direct-delivery-dialog"><p>' + text1 + '</p><p>' + shipto + '</p><p>' + text2 + '</p>';
    html      = html + '<hr><p>';
    html      = html + '<input type="button" value="' + kivi.t8('Yes') + '" size="30" onclick="kivi.Reclamation.direct_delivery_callback(true,' + save_params_string + ')">';
    html      = html + '&nbsp;';
    html      = html + '<input type="button" value="' + kivi.t8('No')  + '" size="30" onclick="kivi.Reclamation.direct_delivery_callback(false,' + save_params_string + ')">';
    html      = html + '</p></div>';
    $(html).hide().appendTo('#reclamation_form');

    kivi.popup_dialog({id: 'direct-delivery-dialog',
                       dialog: {title:  kivi.t8('Carry over shipping address'),
                                height: 300,
                                width:  500 }});
  };

  ns.follow_up_window = function() {
    var id   = $('#id').val();
    var type = $('#type').val();
    var number_info = $('#reclamation_record_number').val();

    var name_info = '';
    if ($('#type').val() == 'sales_reclamation') {
      name_info = $('#reclamation_customer_id_name').val();
    } else if ($('#type').val() == 'purchase_reclamation') {
      name_info = $('#reclamation_vendor_id_name').val();
    }

    var info = '';
    if (number_info !== '') { info += ' (' + number_info + ')' }
    if (name_info   !== '') { info += ' (' + name_info + ')' }

    if (!$('#follow_up_rowcount').length) {
      $('<input type="hidden" name="follow_up_rowcount"        id="follow_up_rowcount">').appendTo('#reclamation_form');
      $('<input type="hidden" name="follow_up_trans_id_1"      id="follow_up_trans_id_1">').appendTo('#reclamation_form');
      $('<input type="hidden" name="follow_up_trans_type_1"    id="follow_up_trans_type_1">').appendTo('#reclamation_form');
      $('<input type="hidden" name="follow_up_trans_info_1"    id="follow_up_trans_info_1">').appendTo('#reclamation_form');
      $('<input type="hidden" name="follow_up_trans_subject_1" id="follow_up_trans_subject_1">').appendTo('#reclamation_form');
    }
    $('#follow_up_rowcount').val(1);
    $('#follow_up_trans_id_1').val(id);
    $('#follow_up_trans_type_1').val(type);
    $('#follow_up_trans_info_1').val(info);
    $('#follow_up_trans_subject_1').val($('#reclamation_transaction_description').val());

    follow_up_window();
  };

  ns.create_part = function() {
    var data = $('#reclamation_form').serializeArray();
    data.push({ name: 'action', value: 'Reclamation/create_part' });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.get_selected_rows = function() {
    let selected_rows = [];
    $('[name^="multi_id_"]').each( function() {
      if (this.checked) {
        selected_rows.push($(this).parents("tr").first());
      }
    });
    return selected_rows;
  }

  ns.toggle_selected_rows = function() {
    let selected_rows = [];
    $('[name^="multi_id_"]').each( function() {
      this.checked = !this.checked;
    });
    return selected_rows;
  }

  ns.delete_selected_rows = function() {
    selected_rows = ns.get_selected_rows();
    let row_count = selected_rows.length;
    if (row_count == 0) {
      alert(kivi.t8("No row selected."));
      return;
    }
    if (!confirm(kivi.t8("Do you want delete #1 rows?", [row_count]))) {
      return;
    }
    selected_rows.forEach(function(row) {
      $(row.parents("tbody").first()).remove();
    });
    ns.renumber_positions();
    ns.recalc_amounts_and_taxes();
  };

  ns.set_selected_to_value = function(value_name) {
    let value = $('[name="' + value_name + '_for_selected"]').val();
    let selected_rows = ns.get_selected_rows();
    selected_rows.forEach(function(row) {
      $(row).find(
        '[name="reclamation.reclamation_items[].' + value_name  + '"]'
      ).val(
        value
      );
    });
  };

});

$(function() {
  if ($('#type').val() == 'sales_reclamation') {
    $('#reclamation_customer_id').change(kivi.Reclamation.reload_cv_dependent_selections);
  } else {
    $('#reclamation_vendor_id').change(kivi.Reclamation.reload_cv_dependent_selections);
  }

  $('#reclamation_currency_id').change(kivi.Reclamation.update_exchangerate);
  $('#reclamation_transdate_as_date').change(kivi.Reclamation.update_exchangerate);
  $('#reclamation_exchangerate_as_null_number').change(kivi.Reclamation.exchangerate_changed);

  $('#add_item_parts_id').on('set_item:PartPicker', function() {
    kivi.Reclamation.update_item_input_row();
  });

  $('.add_item_input').keydown(function(event) {
    if (event.keyCode == 13) {
      event.preventDefault();
      kivi.Reclamation.add_item();
      return false;
    }
  });

  kivi.Reclamation.init_row_handlers();

  $('#row_table_id').on('sortstop', function(event, ui) {
    $('#row_table_id thead a img').remove();
    kivi.Reclamation.renumber_positions();
  });

  $('#expand_all').on('click', function(event) {
    event.preventDefault();
    if ($('#expand_all').data('expanded') == 1) {
      $('#expand_all').data('expanded', 0);
      $('#expand_all').attr('src', 'image/expand.svg');
      $('#expand_all').attr('alt', kivi.t8('Show all details'));
      $('#expand_all').attr('title', kivi.t8('Show all details'));
      $('.row_entry').each(function(idx, elt) {
        kivi.Reclamation.hide_second_row(elt);
      });
    } else {
      $('#expand_all').data('expanded', 1);
      $('#expand_all').attr('src', "image/collapse.svg");
      $('#expand_all').attr('alt', kivi.t8('Hide all details'));
      $('#expand_all').attr('title', kivi.t8('Hide all details'));
      kivi.Reclamation.load_all_second_rows();
      $('.row_entry').each(function(idx, elt) {
        kivi.Reclamation.show_second_row(elt);
      });
    }
    return false;
  });

  $('#select_all').click( function() {
    var checked = this.checked
    $('[name^="multi_id_"]').each(function() {
      this.checked =  checked;
    });
  });

  $('.reformat_number_as_null_number').change(kivi.Reclamation.reformat_number_as_null_number);

});
