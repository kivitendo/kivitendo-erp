namespace('kivi.GoBD', function(ns) {
  ns.grey_invalid_options = function(el){
    console.log(el);
    if ($(el).prop('checked')) {
      $(el).closest('tr').find('input.datepicker').prop('disabled', false).datepicker('enable');
      $(el).closest('tr').find('select').prop('disabled', 0);
    } else {
      $(el).closest('tr').find('input.datepicker').prop('disabled', true).datepicker('disable');
      $(el).closest('tr').find('select').prop('disabled', 1);
    }
  }

  ns.update_all_radio = function () {
    $('input[type=radio]').each(function(i,e) {ns.grey_invalid_options (e) });
  }

  ns.setup = function() {
    ns.update_all_radio();
    $('input[type=radio]').change(ns.update_all_radio);
  }
});

$(kivi.GoBD.setup);
