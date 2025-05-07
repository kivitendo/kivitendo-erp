namespace('kivi.Invoice', function(ns) {
  ns.check_cv = function() {
      if ($('#record_customer_id').length && $('#record_customer_id').val() === '') {
        alert(kivi.t8('Please select a customer.'));
        return false;
      }

      if ($('#record_vendor_id').length && $('#record_vendor_id').val() === '') {
        alert(kivi.t8('Please select a vendor.'));
        return false;
      }
    return true;
  };

  ns.check_duplicate_parts = function(question) {
    var id_arr = $('[name="record.items[].parts_id"]').map(function() { return this.value; }).get();

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
    if ($('#record_reqdate_as_date').val() === '') {
      alert(kivi.t8('Please select a delivery date.'));
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

    var data = $('#invoice_form').serializeArray();
    data.push({ name: 'action', value: 'Invoice/' + action });

    if (form_params) {
      if (Array.isArray(form_params)) {
        form_params.forEach(function(item) {
          data.push(item);
        });
      } else {
        data.push(form_params);
      }
    }

    if (params.data)
      data = $.merge(data, params.data);

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.delete_invoice = function() {
    var data = $('#invoice_form').serializeArray();
    data.push({ name: 'action', value: 'Invoice/delete' });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.show_print_options = function(params) {
    if (!ns.check_cv()) return;

    const warn_on_duplicates = params.warn_on_duplicates;
    const warn_on_reqdate    = params.warn_on_reqdate;

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

    var data = $('#invoice_form').serializeArray();
    data = data.concat($('#print_options_form').serializeArray());
    data.push({ name: 'action', value: 'Invoice/print' });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  var email_dialog;

  ns.setup_send_email_dialog = function() {
    kivi.SalesPurchase.show_all_print_options_elements();
    kivi.SalesPurchase.show_print_options_elements([ 'sendmode', 'media', 'copies', 'remove_draft' ], false);

    $('#print_options_form table').first().remove().appendTo('#email_form_print_options');

    $('select#format').change(kivi.Invoice.adjust_email_attachment_name_for_template_format);
    kivi.Invoice.adjust_email_attachment_name_for_template_format();

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
      beforeClose: kivi.Order.finish_send_email_dialog,
      close: function(event, ui) {
        email_dialog.remove();
      }
    };

    $('#' + id).remove();

    email_dialog = $('<div style="display:none" id="' + id + '"></div>').appendTo('body');
    email_dialog.html(html);
    email_dialog.dialog(dialog_params);

    kivi.Invoice.setup_send_email_dialog();

    $('.cancel').click(ns.close_email_dialog);

    return true;
  };

  ns.send_email = function() {
    // push button only once -> slow response from mail server
    ns.email_dialog_disable_send();

    var data = $('#invoice_form').serializeArray();
    data = data.concat($('[name^="email_form."]').serializeArray());
    data = data.concat($('[name^="print_options."]').serializeArray());
    data.push({ name: 'action', value: 'Invoice/send_email' });
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

  ns.adjust_email_attachment_name_for_template_format = function() {
    var $filename_elt = $('#email_form_attachment_filename');
    var $format_elt   = $('select#format');

    if (!$filename_elt || !$format_elt)
      return;

    var format   = $format_elt.val().toLowerCase();
    var new_ext  = format == 'html' ? 'html' : format == 'opendocument' ? 'odt' : 'pdf';
    var filename = $filename_elt.val();

    $filename_elt.val(filename.replace(/[^.]+$/, new_ext));
  };

  ns.set_number_in_title = function(elt) {
    $('#nr_in_title').html($(elt).val());
  };

  ns.reload_cv_dependent_selections = function() {
    $('#record_shipto_id').val('');
    var data = $('#invoice_form').serializeArray();
    data.push({ name: 'action', value: 'Invoice/customer_vendor_changed' });

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
      $('#record_currency_id').val($('#old_currency_id').val());
      return;
    }

    var rate_input = $('#record_exchangerate_as_null_number');
    // unset exchangerate if currency changed
    if ($('#record_currency_id').val() !== $('#old_currency_id').val()) {
      rate_input.val('');
    }

    // only set exchangerate if unset
    if (rate_input.val() !== '') {
      return;
    }

    var data = $('#invoice_form').serializeArray();
    data.push({ name: 'action', value: 'Invoice/update_exchangerate' });

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
          $('#record_exchangerate_as_null_number').data('validate', 'required');
          $('#exchangerate_settings').show();
        } else {
          rate_input.val('');
          $('#record_exchangerate_as_null_number').data('validate', '');
          $('#exchangerate_settings').hide();
        }
        if ($('#record_currency_id').val() != $('#old_currency_id').val() ||
            !data.is_standard && data.exchangerate != $('#old_exchangerate').val()) {
          kivi.display_flash('warning', kivi.t8('You have changed the currency or exchange rate. Please check prices.'));
        }
        $('#old_currency_id').val($('#record_currency_id').val());
        $('#old_exchangerate').val(data.exchangerate);
      }
    });
  };

  ns.exchangerate_changed = function(event) {
    if (kivi.parse_amount($('#record_exchangerate_as_null_number').val()) != kivi.parse_amount($('#old_exchangerate').val())) {
      kivi.display_flash('warning', kivi.t8('You have changed the currency or exchange rate. Please check prices.'));
      $('#old_exchangerate').val($('#record_exchangerate_as_null_number').val());
    }
  };

  ns.recalc_amounts_and_taxes = function() {
    if (!kivi.validate_form('#invoice_form')) return;

    var data = $('#invoice_form').serializeArray();
    data.push({ name: 'action', value: 'Invoice/recalc_amounts_and_taxes' });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.unit_change = function(event) {
    var row           = $(event.target).parents("tbody").first();
    var item_id_dom   = $(row).find('[name="item_ids[+]"]');
    var sellprice_dom = $(row).find('[name="record.items[].sellprice_as_number"]');
    var select_elt    = $(row).find('[name="record.items[].unit"]');

    var oldval = $(select_elt).data('oldval');
    $(select_elt).data('oldval', $(select_elt).val());

    var data = $('#invoice_form').serializeArray();
    data.push({ name: 'action',           value: 'Invoice/unit_changed'     },
              { name: 'item_id',          value: item_id_dom.val()        },
              { name: 'old_unit',         value: oldval                   },
              { name: 'sellprice_dom_id', value: sellprice_dom.attr('id') });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.update_sellprice = function(item_id, price_str) {
    var row       = $('#item_' + item_id).parents("tbody").first();
    var price_elt = $(row).find('[name="record.items[].sellprice_as_number"]');
    var html_elt  = $(row).find('[name="sellprice_text"]');
    price_elt.val(price_str);
    html_elt.html(price_str);
  };

  ns.load_second_row = function(row) {
    var item_id_dom = $(row).find('[name="items[+]"]');
    var div_elt     = $(row).find('[name="second_row"]');

    if ($(div_elt).data('loaded') == 1) {
      return;
    }
    var data = $('#invoice_form').serializeArray();
    data.push({ name: 'action',     value: 'Invoice/load_second_rows' },
              { name: 'item_ids[]', value: item_id_dom.val()        });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.load_all_second_rows = function() {
    var rows = $('.row_entry').filter(function(idx, elt) {
      return $(elt).find('[name="second_row"]').data('loaded') != 1;
    });

    var item_ids = $.map(rows, function(elt) {
      var item_id = $(elt).find('[name="item_ids[+]"]').val();
      return { name: 'item_ids[]', value: item_id };
    });

    if (item_ids.length == 0) {
      return;
    }

    var data = $('#invoice_form').serializeArray();
    data.push({ name: 'action', value: 'Invoice/load_second_rows' });
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

    var data = $('#record_form').serializeArray();
    data.push({ name: 'action',   value: 'Invoice/reorder_items' },
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
        insert_before_item_id = $(elt).find('[name="item_ids[+]"]').val();
        return false;
      }
    });

    return insert_before_item_id;
  };

  ns.update_item_input_row = function() {
    if (!ns.check_cv()) return;

    var data = $('#invoice_form').serializeArray();
    data.push({ name: 'action', value: 'Invoice/update_item_input_row' });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.add_item = function() {
    if ($('#add_item_parts_id').val() === '') return;
    if (!ns.check_cv()) return;

    $('#row_table_id thead a img').remove();

    var insert_before_item_id = ns.get_insert_before_item_id($('#add_item_position').val());

    var data = $('#invoice_form').serializeArray();
    data.push({ name: 'action', value: 'Invoice/add_item' },
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
    data = data.concat($('#invoice_form').serializeArray());
    data.push({ name: 'action', value: 'Invoice/add_multi_items' },
              { name: 'insert_before_item_id', value: insert_before_item_id });
    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.delete_item_row = function(clicked) {
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
    var description_elt     = $(row).find('[name="record.items[].description"]');
    var longdescription_elt = $(row).find('[name="record.items[].longdescription"]');

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
    var item_id_dom = $(row).find('[name="item_ids[+]"]');

    var data = $('#invoice_form').serializeArray();
    data.push({ name: 'action',  value: 'Invoice/price_popup' },
              { name: 'item_id', value: item_id_dom.val()   });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.set_price_and_source_text = function(item_id, source, descr, price_str, price_editable) {
    var row        = $('#item_' + item_id).parents("tbody").first();
    var source_elt = $(row).find('[name="record.items[].active_price_source"]');
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
      var price_elt = $(row).find('[name="record.items[].sellprice_as_number"]');
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
    var source_elt = $(row).find('[name="record.items[].active_discount_source"]');
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
      var discount_elt = $(row).find('[name="record.items[].discount_as_percent"]');
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
    var item_id_dom = $(row).find('[name="item_ids[+]"]');

    var data = $('#invoice_form').serializeArray();
    data.push({ name: 'action', value: 'Invoice/update_row_from_master_data' });
    data.push({ name: 'item_ids[]', value: item_id_dom.val() });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.update_all_rows_from_master_data = function() {
    var item_ids = $.map($('.row_entry'), function(elt) {
      var item_id = $(elt).find('[name="item_ids[+]"]').val();
      return { name: 'item_ids[]', value: item_id };
    });

    if (item_ids.length == 0) {
      return;
    }

    var data = $('#invoice_form').serializeArray();
    data.push({ name: 'action', value: 'Invoice/update_row_from_master_data' });
    data = data.concat(item_ids);

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.show_calculate_qty_dialog = function(clicked) {
    var row        = $(clicked).parents("tbody").first();
    var input_id   = $(row).find('[name="record.items[].qty_as_number"]').attr('id');
    var formula_id = $(row).find('[name="formula[+]"]').attr('id');

    calculate_qty_selection_dialog("", input_id, "", formula_id);
    return true;
  };

  ns.edit_custom_shipto = function() {
    if (!ns.check_cv()) return;

    kivi.SalesPurchase.edit_custom_shipto();
  };

  ns.follow_up_window = function() {
    var id   = $('#id').val();
    var type = $('#type').val();

    var number_info = '';
    if ($('#record_ordnumber').length) {
      number_info = $('#record_ordnumber').val();
    } else if ($('#record_quonumber').length) {
      number_info = $('#record_quonumber').val();
    }

    var name_info = '';
    if ($('#record_customer_id_name').length) {
      name_info = $('#record_customer_id_name').val();
    } else if ($('#record_vendor_id_name').length) {
      name_info = $('#record_vendor_id_name').val();
    }

    var info = '';
    if (number_info !== '') { info += ' (' + number_info + ')' }
    if (name_info   !== '') { info += ' (' + name_info + ')' }

    if (!$('#follow_up_rowcount').length) {
      $('<input type="hidden" name="follow_up_rowcount"        id="follow_up_rowcount">').appendTo('#record_form');
      $('<input type="hidden" name="follow_up_trans_id_1"      id="follow_up_trans_id_1">').appendTo('#record_form');
      $('<input type="hidden" name="follow_up_trans_type_1"    id="follow_up_trans_type_1">').appendTo('#record_form');
      $('<input type="hidden" name="follow_up_trans_info_1"    id="follow_up_trans_info_1">').appendTo('#record_form');
      $('<input type="hidden" name="follow_up_trans_subject_1" id="follow_up_trans_subject_1">').appendTo('#record_form');
    }
    $('#follow_up_rowcount').val(1);
    $('#follow_up_trans_id_1').val(id);
    $('#follow_up_trans_type_1').val(type);
    $('#follow_up_trans_info_1').val(info);
    $('#follow_up_trans_subject_1').val($('#record_transaction_description').val());

    follow_up_window();
  };

  ns.create_part = function() {
    var data = $('#invoice_form').serializeArray();
    data.push({ name: 'action', value: 'Invoice/create_part' });
    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.check_cusordnumber_presence = function() {
    if ($('#record_cusordnumber').length && $('#record_cusordnumber').val() === '') {
      return confirm(kivi.t8('The customer order number is missing. Do you want to continue anyway?'));
    }
    return true;
  };
});

$(function() {
  if ($('#record_customer_id').length) {
    $('#record_customer_id').change(kivi.Invoice.reload_cv_dependent_selections);
  } else {
    $('#record_vendor_id').change(kivi.Invoice.reload_cv_dependent_selections);
  }

  $('#record_currency_id').change(kivi.Invoice.update_exchangerate);
  $('#record_transdate_as_date').change(kivi.Invoice.update_exchangerate);
  $('#record_exchangerate_as_null_number').change(kivi.Invoice.exchangerate_changed);

  $('#add_item_parts_id').on('set_item:PartPicker', function() {
    kivi.Invoice.update_item_input_row();
  });

  $('.add_item_input').keydown(function(event) {
    if (event.keyCode == 13) {
      event.preventDefault();
      kivi.Invoice.add_item();
      return false;
    }
  });

  kivi.Invoice.init_row_handlers();

  $('#row_table_id').on('sortstop', function(event, ui) {
    $('#row_table_id thead a img').remove();
    kivi.Invoice.renumber_positions();
  });

  $('#expand_all').on('click', function(event) {
    event.preventDefault();
    if ($('#expand_all').data('expanded') == 1) {
      $('#expand_all').data('expanded', 0);
      $('#expand_all').attr('src', 'image/expand.svg');
      $('#expand_all').attr('alt', kivi.t8('Show all details'));
      $('#expand_all').attr('title', kivi.t8('Show all details'));
      $('.row_entry').each(function(idx, elt) {
        kivi.Invoice.hide_second_row(elt);
      });
    } else {
      $('#expand_all').data('expanded', 1);
      $('#expand_all').attr('src', "image/collapse.svg");
      $('#expand_all').attr('alt', kivi.t8('Hide all details'));
      $('#expand_all').attr('title', kivi.t8('Hide all details'));
      kivi.Invoice.load_all_second_rows();
      $('.row_entry').each(function(idx, elt) {
        kivi.Invoice.show_second_row(elt);
      });
    }
    return false;
  });

  $('.reformat_number_as_null_number').change(kivi.Invoice.reformat_number_as_null_number);

});
