namespace('kivi.CustomerVendor', function() {

  this.selectShipto = function() {
    var shiptoId = $('#shipto_shipto_id').val();

    if( shiptoId ) {
      var url = 'controller.pl?action=CustomerVendor/ajaj_get_shipto&id='+ $('#cv_id').val() +'&db='+ $('#db').val() +'&shipto_id='+ shiptoId;

      $.getJSON(url, function(data) {
        for(var key in data)
          $(document.getElementById('shipto_'+ key)).val(data[key]);

        $('#action_delete_shipto').show();
      });
    }
    else {
      $('#shipto :input').not(':button, :submit, :reset, :hidden').val('');

      $('#action_delete_shipto').hide();
    }
  };

  this.selectDelivery = function(fromDate, toDate) {
    var deliveryId = $('#delivery_id').val();

    if( !deliveryId )
      $("#delivery").empty();
    else {
      var url = 'controller.pl?action=CustomerVendor/get_delivery&id='+ $('#cv_id').val() +'&db='+ $('#db').val() +'&shipto_id='+ $('#delivery_id').val();

      if( fromDate && toDate )
        url += '&delivery_from='+ fromDate +'&delivery_to='+ toDate;

      $('#delivery').load(url);
    }
  };

  this.selectContact = function() {
    var contactId = $('#contact_cp_id').val();

    if( contactId ) {
      var url = 'controller.pl?action=CustomerVendor/ajaj_get_contact&id='+ $('#cv_id').val() +'&db='+ $('#db').val() +'&contact_id='+ contactId;

      $.getJSON(url, function(data) {
        var contact = data.contact;
        for(var key in contact)
          $(document.getElementById('contact_'+ key)).val(contact[key]);

        var cvars = data.contact_cvars;
        for(var key in cvars)
          $(document.getElementById('contact_cvar_'+ key)).val(cvars[key]);

        $('#action_delete_contact').show();
      });
    }
    else {
      $('#contacts :input').not(':button, :submit, :reset, :hidden').val('').removeAttr('checked').removeAttr('selected');

      $('#action_delete_contact').hide();
    }

    $('#contact_cp_title_select, #contact_cp_abteilung_select').val('');
  };


  this.showMap = function(prefix) {
    var searchStmts = [
      '#street',
      ', ',
      '#zipcode',
      ' ',
      '#city',
      ', ',
      '#country'
    ];

    var searchString = "";

    for(var i in searchStmts) {
      var stmt = searchStmts[i];
      if( stmt.charAt(0) == '#' ) {
        var val = $('#'+ prefix + stmt.substring(1)).val();
        if( val )
          searchString += val;
      }
      else
        searchString += stmt;
    }

    var url = 'https://maps.google.com/maps?q='+ encodeURIComponent(searchString);

    window.open(url, '_blank');
    window.focus();
  };

  this.showHistoryWindow = function(id) {
    var xPos = (screen.width - 800) / 2;
    var yPos = (screen.height - 500) / 2;
    var parm = "left="+ xPos +",top="+ yPos +",width=800,height=500,status=yes,scrollbars=yes";
    var url = "common.pl?INPUT_ENCODING=UTF-8&action=show_history&longdescription=&input_name="+ encodeURIComponent(id);
    window.open(url, "_new_generic", parm);
  };
});
