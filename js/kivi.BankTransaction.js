namespace('kivi.BankTransaction', function(ns) {
  "use strict";

  ns.assign_invoice = function(bank_transaction_id) {
    kivi.popup_dialog({
      url:    'controller.pl?action=BankTransaction/assign_invoice',
      data:   '&bt_id=' + bank_transaction_id,
      type:   'POST',
      id:     'assign_invoice_window',
      dialog: { title: kivi.t8('Assign invoice') }
    });
    return true;
  };

  ns.add_invoices = function(bank_transaction_id, proposal_id) {

    $.ajax({
      url: 'controller.pl?action=BankTransaction/ajax_payment_suggestion&bt_id=' + bank_transaction_id  + '&prop_id=' + proposal_id,
      success: function(data) {
        $('#assigned_invoices_' + bank_transaction_id + "_" + proposal_id).html(data.html);
        $('#sources_' + bank_transaction_id + "_" + proposal_id + ',' +
          '#memos_'   + bank_transaction_id + "_" + proposal_id).show();
        $('[data-proposal-id=' + proposal_id + ']').hide();

        ns.update_invoice_amount(bank_transaction_id);
      }
    });
  };

  ns.delete_invoice = function(bank_transaction_id, proposal_id) {
    var $inputs = $('#sources_' + bank_transaction_id + "_" + proposal_id + ',' +
                    '#memos_'   + bank_transaction_id + "_" + proposal_id);

    $('[data-proposal-id=' + proposal_id + ']').show();
    $('#assigned_invoices_' + bank_transaction_id + "_" + proposal_id).html('');
    $('#extra_row_' + bank_transaction_id + '_' + proposal_id).remove();

    $inputs.hide();
    $inputs.val('');

    ns.update_invoice_amount(bank_transaction_id);
  };

  ns.create_invoice = function(bank_transaction_id) {
    kivi.popup_dialog({
      url:    'controller.pl?action=BankTransaction/create_invoice',
      data:   '&bt_id=' + bank_transaction_id + "&filter.bank_account=" + $('#filter_bankaccount').val() + '&filter.fromdate=' + $('#filter_fromdate').val() + '&filter.todate=' + $('#filter_todate').val(),
      type:   'POST',
      id:     'create_invoice_window',
      dialog: { title: kivi.t8('Create invoice') }
    });
    return true;
  };


  ns.filter_invoices = function() {
    var url="controller.pl?action=BankTransaction/ajax_add_list&" + $("#assign_invoice_window form").serialize();
    $.ajax({
      url: url,
      success: function(data) {
        $("#record_list_filtered_list").html(data.html);
      }
    });
  }

  ns.add_selected_invoices = function() {
    var bank_transaction_id = $("#assign_invoice_window_form").data("bank-transaction-id");
    var url                 ="controller.pl?action=BankTransaction/ajax_accept_invoices&bt_id=" + bank_transaction_id + '&' + $("#assign_invoice_window form").serialize();

    $.ajax({
      url: url,
      success: function(new_html) {
        $('#bt_rows_' + bank_transaction_id).append(new_html);
        $('#assign_invoice_window').dialog('close');
        ns.update_invoice_amount(bank_transaction_id);
      }
    });
  }

  ns.update_invoice_amount = function(bank_transaction_id) {
    var $container = $('#invoice_amount_' + bank_transaction_id);
    var amount     = $container.data('invoice-amount') * 1;

    $('[id^="' + bank_transaction_id + '."]').each(function(idx, elt) {
      amount += $(elt).data('invoice-amount');
    });

    $container.html(kivi.format_amount(amount, 2));
  };

  ns.init_list = function(ui_tab) {
    $('#check_all').checkall('INPUT[name^="proposal_ids"]');

    $('.sort_link').each(function() {
      var _href = $(this).attr("href");
      $(this).attr("href", _href + "&filter.fromdate=" + $('#filter_fromdate').val() + "&filter.todate=" + $('#filter_todate').val());
    });

    $.cookie('jquery_ui_tab_bt_tabs', ui_tab);
  };

  ns.show_set_all_sources_memos_dialog = function(sources_selector, memos_selector) {
    var dlg_id = 'set_all_sources_memos_dialog';
    var $dlg   = $('#' + dlg_id);

    $dlg.data('sources-selector', sources_selector);
    $dlg.data('memos-selector',   memos_selector);

    $('#set_all_sources').val('');
    $('#set_all_memos').val('');

    kivi.popup_dialog({
      id: dlg_id,
      dialog: {
        title: kivi.t8('Set all source and memo fields')
      }
    });
  };

  ns.set_all_sources_memos = function(sources_selector, memos_selector) {
    var $dlg = $('#set_all_sources_memos_dialog');

    ['sources', 'memos'].forEach(function(type) {
      var value = $('#set_all_' + type).val();
      if (value !== '')
        $($dlg.data(type + '-selector')).each(function(idx, input) {
          $(input).val(value);
        });
    });

    $dlg.dialog('close');
  };
});
