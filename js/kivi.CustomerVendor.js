namespace('kivi.CustomerVendor', function(ns) {

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

  this.setCustomVariablesFromAJAJ = function(cvars) {
    for (var key in cvars) {
      var cvar  = cvars[key];
      var $ctrl = $('#contact_cvars_'+ key);

      console.log($ctrl, cvar);

      if (cvar.type == 'bool')
        $ctrl.prop('checked', cvar.value == 1 ? 'checked' : '');

      else if ((cvar.type == 'customer') || (cvar.type == 'vendor'))
        kivi.CustomerVendorPicker($ctrl).set_item({ id: cvar.id, name: cvar.value });

      else if (cvar.type == 'part')
        kivi.PartPicker($ctrl).set_item({ id: cvar.id, name: cvar.value });

      else
        $ctrl.val(cvar.value);
    }
  };

  this.selectContact = function(params) {
    var contactId = $('#contact_cp_id').val();

	  var url = 'controller.pl?action=CustomerVendor/ajaj_get_contact&id='+ $('#cv_id').val() +'&db='+ $('#db').val() +'&contact_id='+ contactId;

    $.getJSON(url, function(data) {
      var contact = data.contact;
      for(var key in contact)
        $(document.getElementById('contact_'+ key)).val(contact[key])

      kivi.CustomerVendor.setCustomVariablesFromAJAJ(data.contact_cvars);

      if ( contactId )
        $('#action_delete_contact').show();
      else
        $('#action_delete_contact').hide();

      if ( params.onFormSet )
        params.onFormSet();
    });

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

  this.MapWidget = function(prefix, source_address)
  {
    var $mapSearchElements = [];
    var $widgetWrapper;

    var init = function() {
      if( $mapSearchElements.length > 0 )
        return;

      for(var i in mapSearchStmts) {
        var stmt = mapSearchStmts[i];
        if( stmt.charAt(0) == '#' ) {
          var $elem = $('#'+ prefix + stmt.substring(1));
          if( $elem )
            $mapSearchElements.push($elem);
        }
      }
    };

    var isNotEmpty = function() {
      for(var i in $mapSearchElements)
        if( ($mapSearchElements[i].attr('id') != prefix + 'country') && ($mapSearchElements[i].val() == '') )
          return false;
      return true;
    };

    var showMap = function() {
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

      source_address = source_address || '';
      var query      = source_address != '' ? 'saddr=' + encodeURIComponent(source_address) + '&daddr=' : 'q=';
      var url        = 'https://maps.google.com/maps?' + query + encodeURIComponent(searchString);

      window.open(url, '_blank');
      window.focus();
    };

    var render = function(widgetWrapper) {
      init();

      $widgetWrapper = $(widgetWrapper);

      $widgetWrapper
        .html('<img src="image/map.png" alt="'+ kivi.t8("Map") +'" title="'+ kivi.t8("Map") +'" />')
        .click(function() {
          showMap();
        });
      for(var i in $mapSearchElements)
        $mapSearchElements[i].keyup(testInputs);
      this.testInputs();
    };

    var testInputs = function() {
      init();

      if( isNotEmpty() )
        $widgetWrapper.show();
      else
        $widgetWrapper.hide();
    };

    this.render = render;
    this.testInputs = testInputs;
  };

  this.showHistoryWindow = function(id) {
    var xPos = (screen.width - 800) / 2;
    var yPos = (screen.height - 500) / 2;
    var parm = "left="+ xPos +",top="+ yPos +",width=800,height=500,status=yes,scrollbars=yes";
    var url = "common.pl?INPUT_ENCODING=UTF-8&action=show_history&longdescription=&input_name="+ encodeURIComponent(id);
    window.open(url, "_new_generic", parm);
  };

  this.update_dial_action = function($input) {
    var $action = $('#' + $input.prop('id') + '-dial-action');

    if (!$action)
      return true;

    var number = $input.val().replace(/\s+/g, '');
    if (number == '')
      $action.hide();
    else
      $action.prop('href', 'controller.pl?action=CTI/call&number=' + encodeURIComponent(number)).show();

    return true;
  };

  this.init_dial_action = function(input) {
    if ($('#_cti_enabled').val() != 1)
      return false;

    var $input    = $(input);
    var action_id = $input.prop('id') + '-dial-action';

    if (!$('#' + action_id).size()) {
      var $action = $('<a href="" id="' + action_id + '" class="cti_call_action" target="_blank" tabindex="-1"></a>');
      $input.wrap('<span nobr></span>').after($action);

      $input.change(function() { kivi.CustomerVendor.update_dial_action($input); });
    }

    kivi.CustomerVendor.update_dial_action($input);

    return true;
  };

  this.inline_report = function(target, source, data){
    $.ajax({
      url:        source,
      success:    function (rsp) {
        $(target).html(rsp);
        $(target).find('.paginate').find('a').click(function(event){ ns.redirect_event(event, target) });
        $(target).find('a.report-generator-header-link').click(function(event){ ns.redirect_event(event, target) });
      },
      data:       data,
    });
  };
  this.redirect_event = function(event, target){
    event.preventDefault();
    ns.inline_report(target, event.target + '', {});
  };
});

function local_reinit_widgets() {
  $('#cv_phone,#shipto_shiptophone,#contact_cp_phone1,#contact_cp_phone2,#contact_cp_mobile1,#contact_cp_mobile2').each(function(idx, elt) {
    kivi.CustomerVendor.init_dial_action($(elt));
  });
}
