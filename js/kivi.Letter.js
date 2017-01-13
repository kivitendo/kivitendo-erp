namespace('kivi.Letter', function(ns) {
  "use strict";

  $(function() {
    $('#letter_customer_id,#letter_vendor_id').change(function(){
      var data = $('form').serializeArray();
      data.push({ name: 'action', value: 'Letter/update_contacts' });
      $.post('controller.pl', data, kivi.eval_json_result);
    });
  });
});
