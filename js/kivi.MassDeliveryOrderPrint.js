namespace('kivi.MassDeliveryOrderPrint', function(ns) {
    
  ns.massConversionFinishProcess = function() {
    $('#mass_print_dialog').dialog('close');
  };

  ns.massConversionStarted = function() {
   $('#mdo_start_process_button,.ui-dialog-titlebar button.ui-dialog-titlebar-close').prop('disabled', 'disabled');
   $('#mdo_start_process_abort_link').remove();
   $('#mass_print_dialog').data('timerId', setInterval(function() {
      $.get("controller.pl", {
        action: 'MassDeliveryOrderPrint/mass_mdo_status',
        job_id: $('#mdo_job_id').val()
      }, kivi.eval_json_result);
    }, 5000));
  };

  ns.massConversionPopup = function() {
    kivi.popup_dialog({
      id: 'mass_print_dialog',
      dialog: {
        title: kivi.t8('Generate and print sales delivery orders')
      }
    });
  };

  ns.massConversionFinished = function() {
    clearInterval($('#mass_print_dialog').data('timerId'));
    $('.ui-dialog-titlebar button.ui-dialog-titlebar-close').prop('disabled', '')
  };

  ns.submitMultiOrders = function () {
      $("#old_table_id").remove();
      var checkboxes = $('input[type=checkbox]').filter(function () { return  $(this).prop('checked'); });
      if (checkboxes.size() == 0) {
          alert(kivi.t8("No delievery orders selected, please set one checkbox!"));
          return false;
      }
      
      var tmpform = $("#report_table_id").clone();
      tmpform.hide();
      tmpform.attr('id',"old_table_id");
      tmpform.appendTo("#print_multi_id");
      return kivi.submit_ajax_form('controller.pl?action=MassDeliveryOrderPrint/mass_mdo_print',$('#print_multi_id'));
  };

  ns.setup = function() {
    $('#multi_all').checkall("input[name^='multi_id']");
    $('#print_multi_button').click(kivi.MassDeliveryOrderPrint.submitMultiOrders);
  };
});

$(kivi.MassDeliveryOrderPrint.setup);
