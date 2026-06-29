namespace('kivi.MassInvoiceCreatePrint', function(ns) {
  this.checkSalesOrderSelection = function() {
    if ($("[data-checkall=1]:checked").size() > 0)
      return true;
    alert(kivi.t8('No delivery orders have been selected.'));
    return false;
  };

  this.checkDeliveryOrderSelection = function() {
    if ($("[data-checkall=1]:checked").size() > 0)
      return true;
    alert(kivi.t8('No delivery orders have been selected.'));
    return false;
  };

  this.checkInvoiceSelection = function() {
    if ($("[data-checkall=1]:checked").size() > 0)
      return true;
    alert(kivi.t8('No invoices have been selected.'));
    return false;
  };

  this.createPrintAllInitialize = function() {
    kivi.popup_dialog({
      id: 'create_print_all_dialog',
      dialog: {
        title: kivi.t8('Create and print all invoices')
      }
    });
  };

  this.createPrintAllStartProcess = function() {
    $('#cpa_start_process_button,.ui-dialog-titlebar button.ui-dialog-titlebar-close').prop('disabled', 'disabled');
    $('#cpa_start_process_abort_link').remove();

    var filter = $('[name^=filter\\.]').serializeArray();
    var data = {
      action:             'MassInvoiceCreatePrint/create_print_all_start',
      number_of_invoices: $('#cpa_number_of_invoices').val(),
      bothsided:          $('#cpa_bothsided').val(),
      printer_id:         $('#cpa_printer_id').val(),
      copy_printer_id:    $('#cpa_copy_printer_id').val(),
      transdate:          $('#transdate').val()
    };

    $(filter).each(function(index, obj){ data[obj.name] = obj.value; });

    $.post('controller.pl', data, kivi.eval_json_result);
  };

  this.createPrintAllFinishProcess = function() {
    $('#create_print_all_dialog').dialog('close');
    window.location.href = 'controller.pl?action=MassInvoiceCreatePrint%2flist_invoices&noshow=1';
  };

  this.massConversionStarted = function() {
    $('#create_print_all_dialog').data('timerId', setInterval(function() {
      $.get("controller.pl", {
        action: 'MassInvoiceCreatePrint/create_print_all_status',
        job_id: $('#cpa_job_id').val()
      }, kivi.eval_json_result);
    }, 5000));
  };

  this.massConversionFinished = function() {
    clearInterval($('#create_print_all_dialog').data('timerId'));
    $('.ui-dialog-titlebar button.ui-dialog-titlebar-close').prop('disabled', '')
  };

  ns.showMassPrintOptions = function() {
    $('#printer_options_printer_id').val($('#printer_id').val());

    kivi.popup_dialog({
      id: 'print_options',
      dialog: {
        title: kivi.t8('Print options'),
        width:  600,
        height: 200
      }
    });

    return true;
  };

  ns.showMassPrintOptionsOrDownloadDirectly = function() {
    if (!kivi.MassInvoiceCreatePrint.checkInvoiceSelection())
      return false;

    if ($('#print_options_printer_id').length === 0)
      return kivi.MassInvoiceCreatePrint.massPrint();
    return kivi.MassInvoiceCreatePrint.showMassPrintOptions();
  };

  ns.massPrint = function() {
    $('#print_options').dialog('close');

    $('#printer_id').val($('#print_options_printer_id').val());
    $('#bothsided').val($('#print_options_bothsided').prop('checked') ? 1 : 0);
    $('#action').val('MassInvoiceCreatePrint/print');

    $('#report_form').submit();

    return true;
  };

  this.resetSearchForm = function() {
    $("#filter_table input").val("");
  };
});
