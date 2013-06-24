$(function(){
  $('input.customer_autocomplete').each(function(i,real){
    var dummy = $('#' + real.id + '_name');
    $(dummy).autocomplete({
      source: function(req, rsp) {
        $.ajax({
          url: 'controller.pl?action=CustomerVendor/ajaj_customer_autocomplete',
          dataType: "json",
          data: {
            term: req.term,
            current: function() { real.val },
            obsolete: 0,
          },
          success: function (data){ rsp(data) }
        });
      },
      limit: 20,
      delay: 50,
      select: function(event, ui) {
        $(real).val(ui.item.id);
        $(dummy).val(ui.item.name);
      },
    });
  });
});
