namespace('kivi.CustomerVendor', function(ns) {

  var kivi = namespace('kivi');

  this.selectShipto = function(params) {
    var shiptoId = $('#shipto_shipto_id').val();

    if( shiptoId ) {
      var url = 'controller.pl?action=CustomerVendor/ajaj_get_shipto&id='+ $('#cv_id').val() +'&db='+ $('#db').val() +'&shipto_id='+ shiptoId;

      $.getJSON(url, function(data) {
        for(var key in data)
          $(document.getElementById('shipto_'+ key)).val(data[key]);

        $('#action_delete_shipto').show();

        if( params.onFormSet )
          params.onFormSet();
      });
    }
    else {
      $('#shipto :input').not(':button, :submit, :reset, :hidden').val('');

      $('#action_delete_shipto').hide();

      if( params.onFormSet )
        params.onFormSet();
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

  this.selectContact = function(params) {
    var contactId = $('#contact_cp_id').val();

    if( contactId ) {
      var url = 'controller.pl?action=CustomerVendor/ajaj_get_contact&id='+ $('#cv_id').val() +'&db='+ $('#db').val() +'&contact_id='+ contactId;

      $.getJSON(url, function(data) {
        var contact = data.contact;
        for(var key in contact)
          $(document.getElementById('contact_'+ key)).val(contact[key])

        var cvars = data.contact_cvars;
        for(var key in cvars)
          $(document.getElementById('contact_cvar_'+ key)).val(cvars[key]);

        $('#action_delete_contact').show();

        if( params.onFormSet )
          params.onFormSet();
      });
    }
    else {
      $('#contacts :input').not(':button, :submit, :reset, :hidden').val('').removeAttr('checked').removeAttr('selected');

      $('#action_delete_contact').hide();

      if( params.onFormSet )
        params.onFormSet();
    }

    $('#contact_cp_title_select, #contact_cp_abteilung_select').val('');
  };

  var mapSearchStmts = [
    '#street',
    ', ',
    '#zipcode',
    ' ',
    '#city',
    ', ',
    '#country'
  ];

  this.showMapWidget = function(prefix, widgetWrapper) {
    var result = {
    };

    $(function(){

      widgetWrapper = $(widgetWrapper);

      var mapSearchElements = [];
      for(var i in mapSearchStmts) {
        var stmt = mapSearchStmts[i];
        if( stmt.charAt(0) == '#' ) {
          var elem = $('#'+ prefix + stmt.substring(1));
          if( elem )
            mapSearchElements.push(elem);
        }
      }

      var isNotEmpty = function() {
        for(var i in mapSearchElements)
          if( mapSearchElements[i].val() == '' )
            return false;
        return true;
      };

      widgetWrapper
        .html('<img src="image/map.png" alt="'+ kivi.t8("Map") +'" title="'+ kivi.t8("Map") +'" />')
        .click(function(){
          ns.showMap(prefix);
        });

      var testInputs = function() {
        if( isNotEmpty() )
          widgetWrapper.show();
        else
          widgetWrapper.hide();
      };

      result.testInputs = testInputs;

      $(mapSearchElements)
        .map(function() {
          return this.toArray();
        })
        .keyup(testInputs)

      if( !isNotEmpty() )
        widgetWrapper.hide();

    });

    return result;
  };

  this.showMap = function(prefix) {
    var searchString = "";

    for(var i in mapSearchStmts) {
      var stmt = mapSearchStmts[i];
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
