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
    $('[name=' + proposal_id + ']').remove();

    $.ajax({
      url: 'controller.pl?action=BankTransaction/ajax_payment_suggestion&bt_id=' + bank_transaction_id  + '&prop_id=' + proposal_id,
      success: function(data) {
        $('#assigned_invoices_' + bank_transaction_id).append(data.html);
      }
    });
  };

  ns.delete_invoice = function(bank_transaction_id, proposal_id) {
    $( "#" + bank_transaction_id + "\\." + proposal_id ).remove();
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
        $('#assigned_invoices_' + bank_transaction_id).append(new_html);
        $('#assign_invoice_window').dialog('close');
      }
    });
  }

  ns.init_list = function(ui_tab) {
    $('#check_all').checkall('INPUT[name^="proposal_ids"]');
    $('.sort_link').each(function() {
      var _href = $(this).attr("href");
      $(this).attr("href", _href + "&filter.fromdate=" + $('#filter_fromdate').val() + "&filter.todate=" + $('#filter_todate').val());
    });

    $.cookie('jquery_ui_tab_bt_tabs', ui_tab);
  };
});
