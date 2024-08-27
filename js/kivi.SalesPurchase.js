namespace('kivi.SalesPurchase', function(ns) {
  this.longdescription_dialog_size_percentage = 0;

  this.edit_longdescription = function(row) {
    var $element = $('#longdescription_' + row);

    if (!$element.length) {
      console.error("kivi.SalesPurchase.edit_longdescription: Element #longdescription_" + row + " not found");
      return;
    }

    var params = { element: $element,
                   runningnumber: row,
                   partnumber: $('#partnumber_' + row).val() || '',
                   description: $('#description_' + row).val() || '',
                   default_longdescription: $('#longdescription_' + row).val() || ''
                 };
    this.edit_longdescription_with_params(params);
  };

  this.edit_longdescription_with_params = function(params) {
    var dialog_width    = 800;
    var dialog_height   = 500;
    var textarea_width  = 750;
    var textarea_height = 220;
    if (this.longdescription_dialog_size_percentage != 0) {
      dialog_width    = Math.ceil(window.innerWidth  * this.longdescription_dialog_size_percentage/100);
      dialog_height   = Math.ceil(window.innerHeight * this.longdescription_dialog_size_percentage/100);
      textarea_width  = Math.ceil(dialog_width * 95/100);
      textarea_height = dialog_height - 220;
      if (textarea_height <= 0) textarea_height = 220;
    }

    var $container = $('#popup_edit_longdescription_input_container');
    var $edit      = $('<textarea id="popup_edit_longdescription_input" class="texteditor-in-dialog texteditor-space-for-toolbar" style="width: ' + textarea_width + 'px; height: ' + textarea_height + 'px;"></textarea>');

    $container.children().remove();
    $container.append($edit);

    if (params.element) {
      $container.data('element', params.element);
    }
    if (params.set_function) {
      $container.data('setFunction', params.set_function);
    }

    $edit.val(params.default_longdescription);

    $('#popup_edit_longdescription_runningnumber').html(params.runningnumber);
    $('#popup_edit_longdescription_partnumber').html(params.partnumber);

    var description = params.description.replace(/[\n\r]+/, '');
    if (description.length >= 50)
      description = description.substring(0, 50) + "…";
    $('#popup_edit_longdescription_description').html(description);

    kivi.popup_dialog({
      id:    'edit_longdescription_dialog',
      dialog: {
        title: kivi.t8('Enter longdescription'),
        width:  dialog_width,
        height: dialog_height,
        open:  function() { kivi.focus_ckeditor_when_ready('#popup_edit_longdescription_input'); },
        close: function() { $('#popup_edit_longdescription_input_container').children().remove(); }
      }
    });
  };

  this.set_longdescription = function() {
    if ($('#popup_edit_longdescription_input_container').data('setFunction')) {
      $('#popup_edit_longdescription_input_container').data('setFunction')($('#popup_edit_longdescription_input').val());
    } else {
      $('#popup_edit_longdescription_input_container')
        .data('element')
        .val( $('#popup_edit_longdescription_input').val() );
    }
    $('#edit_longdescription_dialog').dialog('close');
  };

  this.delivery_order_check_transfer_qty = function() {
    var all_match = true;
    var rowcount  = $('input[name=rowcount]').val();
    for (var i = 1; i < rowcount; i++)
      if ($('#stock_in_out_qty_matches_' + i).val() != 1)
        all_match = false;

    if (all_match)
      return true;

    return confirm(kivi.t8('There are still transfers not matching the qty of the delivery order. Stock operations can not be changed later. Do you really want to proceed?'));
  };

  this.oe_warn_save_active_periodic_invoice = function() {
    return confirm(kivi.t8('This sales order has an active configuration for periodic invoices. If you save then all subsequently created invoices will contain those changes as well, but not those that have already been created. Do you want to continue?'));
  };

  this.check_transaction_description = function() {
    if ($('#transaction_description').val() !== '')
      return true;

    alert(kivi.t8('A transaction description is required.'));
    return false;
  };

  this.check_transport_cost_article_presence = function() {
    var $form          = $('#form');
    var wanted_part_id = $form.data('transport-cost-reminder-article-id');

    if (!wanted_part_id)
      return true;

    var rowcount = $('#rowcount').val() * 1;
    for (var row = 1; row <= rowcount; row++)
      if (   (($('#id_'         + row).val() * 1)   === wanted_part_id)
          && (($('#partnumber_' + row).val() || '') !== ''))
        return true;

    var description = $form.data('transport-cost-reminder-article-description');
    return confirm(kivi.t8("The transport cost article '#1' is missing. Do you want to continue anyway?", [ description ]));
  };

  this.on_submit_checks = function() {
    var $button = $(this);
    if (($button.data('check-transfer-qty') == 1) && !kivi.SalesPurchase.delivery_order_check_transfer_qty())
      return false;

    if (($button.data('warn-save-active-periodic-invoice') == 1) && !kivi.SalesPurchase.oe_warn_save_active_periodic_invoice())
      return false;

    if (($button.data('require-transaction-description') == 1) && !kivi.SalesPurchase.check_transaction_description())
      return false;

    return true;
  };

  this.init_on_submit_checks = function() {
     $('input[type=submit]').click(kivi.SalesPurchase.on_submit_checks);
  };

  this.set_duedate_on_reference_date_change = function(reference_field_id) {
    setTimeout(function() {
      var data = {
        action:     'set_duedate',
        invdate:    $('#' + reference_field_id).val(),
        duedate:    $('#duedate').val(),
        payment_id: $('#payment_id').val(),
      };
      $.post('is.pl', data, kivi.eval_json_result);
    });
  };

  // Functions dialog with entering shipping addresses.
  this.shipto_addresses = [];

  this.copy_shipto_address = function () {
    var shipto = this.shipto_addresses[ $('#shipto_to_copy').val() ];
    for (var key in shipto)
      $('#' + key).val(shipto[key]);
  };

  this.clear_shipto_fields = function() {
    var shipto = this.shipto_addresses[0];
    for (var key in shipto)
      $('#' + key).val('');
    $('#shiptocp_gender').val('m');
  };

  this.clear_shipto_id_before_submit = function() {
    var shipto = this.shipto_addresses[0];
    for (var key in shipto)
      if ((key != 'shiptocp_gender') && ($('#' + key).val() !== '')) {
        $('#shipto_id').val('');
        break;
      }
  };

  this.setup_shipto_dialog = function() {
    var $dlg = $('#shipto_dialog');

    $('#shipto_dialog [name^="shipto"]').each(function(idx, elt) {
      $dlg.data("original-" + $(elt).prop("name"), $(elt).val());
    });

    $dlg.data('confirmed', false);

    $('#shiptoname').focus();
  };

  this.submit_custom_shipto = function(id_selector) {
    id_selector = id_selector || '#shipto_id';
    $(id_selector).val('');
    $('#shipto_dialog').data('confirmed', true);
    $('#shipto_dialog').dialog('close');
  };

  this.reset_shipto_fields = function() {
    var $dlg = $('#shipto_dialog');

    $('#shipto_dialog [name^="shipto"]').each(function(idx, elt) {
      $(elt).val($dlg.data("original-" + $(elt).prop("name")));
    });
  };

  this.finish_shipto_dialog = function() {
    if (!$('#shipto_dialog').data('confirmed'))
      kivi.SalesPurchase.reset_shipto_fields();

    $('#shipto_dialog').children().remove().appendTo('#shipto_inputs');

    return true;
  };

  this.edit_custom_shipto = function() {
    $('#shipto_inputs').children().remove().appendTo('#shipto_dialog');

    kivi.popup_dialog({
      id:    'shipto_dialog',
      dialog: {
        height: 600,
        title:  kivi.t8('Edit custom shipto'),
        open:   kivi.SalesPurchase.setup_shipto_dialog,
        close:  kivi.SalesPurchase.finish_shipto_dialog,
      }
    });
  };

  this.show_print_options_elements = function(elements, show) {
    $(elements).each(function(idx, elt) {
      var $elements = $('#print_options_header_' + elt + ',#print_options_input_' + elt);
      if (show)
        $elements.show();
      else
        $elements.hide();
    });
  };

  this.show_all_print_options_elements = function() {
    kivi.SalesPurchase.show_print_options_elements([ 'formname', 'language_id', 'format', 'sendmode', 'media', 'printer_id', 'copies', 'groupitems', 'remove_draft' ], true);
  };

  // Sending records via email.
  this.check_required_email_fields = function() {
    var unset = $('#email_form_to,#email_form_subject,#email_form_message').filter(function(idx, elt) {
      return $(elt).val() === '';
    });

    if (unset.length === 0)
      return true;

    alert(kivi.t8("The recipient, subject or body is missing."));
    $(unset[0]).focus();

    return false;
  };

  this.send_email = function() {
    if (!kivi.SalesPurchase.check_required_email_fields())
      return false;

    // ckeditor gets de-initialized when removing the children from
    // the DOM. Therefore we have to manually preserve its content
    // over the children's relocation.

    var message = $('#email_form_message').val();

    $('#send_email_dialog').children().remove().appendTo('#email_inputs');
    $('#send_email_dialog').dialog('close');

    $('#email_form_message').val(message);

    kivi.submit_form_with_action('#form', $('#form').data('send-email-action'));

    return true;
  };

  this.setup_send_email_dialog = function() {
    kivi.SalesPurchase.show_all_print_options_elements();
    kivi.SalesPurchase.show_print_options_elements([ 'sendmode', 'media', 'copies', 'remove_draft' ], false);

    $('#print_options').children().remove().appendTo('#email_form_print_options');

    kivi.reinit_widgets();

    var to_focus = $('#email_form_to').val() === '' ? 'to' : 'subject';
    $('#email_form_' + to_focus).focus();
  };

  this.finish_send_email_dialog = function() {
    $('#email_form_print_options').children().remove().appendTo('#print_options');
    return true;
  };

  this.show_email_dialog = function(send_action, vc, vc_id_selector) {
    $('#form').data('send-email-action', send_action || 'send_sales_purchase_email');

    vc             = vc             || $('#vc').val();
    vc_id_selector = vc_id_selector || '#' + vc + '_id';
    var vc_id = $(vc_id_selector).val();

    var data = {
      action:       'show_sales_purchase_email_dialog',
      cp_id:        $('#cp_id').val(),
      direct_debit: $('#direct_debit').prop('checked') ? 1 : 0,
      donumber:     $('#donumber').val(),
      format:       $('#format').val(),
      formname:     $('#formname').val(),
      id:           $('#id').val(),
      invnumber:    $('#invnumber').val(),
      language_id:  $('#language_id').val(),
      media:        'email',
      ordnumber:    $('#ordnumber').val(),
      cusordnumber: $('#cusordnumber').val(),
      rowcount:     $('#rowcount').val(),
      quonumber:    $('#quonumber').val(),
      type:         $('#type').val(),
      vc:           vc,
      vc_id:        vc_id,
      project_id:  $('#globalproject_id').val(),
    };

    $('[name^=id_],[name^=partnumber_]').each(function(idx, elt) {
      var val = $(elt).val() || '';
      if (val !== '')
        data[ $(elt).attr('name') ] = val;
    });

    kivi.popup_dialog({
      id:     'send_email_dialog',
      url:    'io.pl',
      load:   kivi.SalesPurchase.setup_send_email_dialog,
      data:   data,
      dialog: {
        height:      600,
        title:       kivi.t8('Send email'),
        beforeClose: kivi.SalesPurchase.finish_send_email_dialog
      }
    });

    return true;
  };

  this.activate_send_email_actions_regarding_printout = function() {
    var selected = $('#email_form_attachment_policy').val();
    $('#email_form_attachment_filename').parents('tr')[selected !== 'no_file' ? 'show' : 'hide']();
    $('#email_form_print_options')[selected !== 'no_file' ? 'show' : 'hide']();
  };

  // Printing records.
  this.setup_print_dialog = function() {
    kivi.SalesPurchase.show_all_print_options_elements();

    $('#print_options').children().remove().appendTo('#print_dialog_print_options');

    $('#print_dialog_print_button').focus();
  };

  this.finish_print_dialog = function() {
    $('#print_dialog_print_options').children().remove().appendTo('#print_options');
  };

  this.print_record = function() {
    $('#print_dialog').dialog('close');

    var action = $('#form').data('print-action');
    if (action.match("^js:"))
      return kivi.run(action.substring(3));

    kivi.submit_form_with_action('#form', action);
  };

  this.show_print_dialog = function(print_action) {
    $('#form').data('print-action', print_action || 'print');

    kivi.popup_dialog({
      id:    'print_dialog',
      dialog: {
        height: 600,
        title:  kivi.t8('Print record'),
        open:   kivi.SalesPurchase.setup_print_dialog,
        close:  kivi.SalesPurchase.finish_print_dialog,
      }
    });
  };
});
