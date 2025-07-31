namespace('kivi.CustomerVendor', function(ns) {

  this.selectShipto = function(params) {
    var shiptoId = $('#shipto_shipto_id').val();
    var url      = 'controller.pl?action=CustomerVendor/ajaj_get_shipto&id='+ $('#cv_id').val() +'&db='+ $('#db').val() +'&shipto_id='+ shiptoId;

    $.getJSON(url, function(data) {
      var shipto = data.shipto;
      for(var key in shipto)
        $('#shipto_'+ key).val(shipto[key])

      kivi.CustomerVendor.setCustomVariablesFromAJAJ(data.shipto_cvars, 'shipto_cvars_');

      if ( shiptoId )
        $('#action_delete_shipto').show();
      else
        $('#action_delete_shipto').hide();

      if ( params.onFormSet )
        params.onFormSet();
    });
  };

  this.selectAdditionalBillingAddress = function(params) {
    var additionalBillingAddressId = $('#additional_billing_address_id').val();
    var url                        = 'controller.pl?action=CustomerVendor/ajaj_get_additional_billing_address&id='+ $('#cv_id').val() +'&db='+ $('#db').val() +'&additional_billing_address_id='+ additionalBillingAddressId;

    $.getJSON(url, function(data) {
      var additional_billing_address = data.additional_billing_address;
      for (var key in additional_billing_address)
        $('#additional_billing_address_'+ key).val(additional_billing_address[key])

      if ( additionalBillingAddressId )
        $('#action_delete_additional_billing_address').show();
      else
        $('#action_delete_additional_billing_address').hide();

      if ( params.onFormSet )
        params.onFormSet();
    });
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

  this.setCustomVariablesFromAJAJ = function(cvars, prefix) {
    for (var key in cvars) {
      var cvar  = cvars[key];
      var $ctrl = $('#' + prefix + key);

      if (cvar.type == 'bool')
        $ctrl.prop('checked', cvar.value == 1 ? 'checked' : '');

      else if ((cvar.type == 'customer') || (cvar.type == 'vendor'))
        kivi.CustomerVendor.Picker($ctrl).set_item({ id: cvar.id, name: cvar.value });

      else if (cvar.type == 'part')
        kivi.Part.Picker($ctrl).set_item({ id: cvar.id, name: cvar.value });

      else
        $ctrl.val(cvar.value).change();
    }
  };

  this.selectContact = function(params) {
    var contactId = $('#contact_cp_id').val();

    var url = 'controller.pl?action=CustomerVendor/ajaj_get_contact&id='+ $('#cv_id').val() +'&db='+ $('#db').val() +'&contact_id='+ contactId;

    $.getJSON(url, function(data) {
      var contact = data.contact;
      for(var key in contact)
        $('#contact_'+ key).val(contact[key])

      kivi.CustomerVendor.setCustomVariablesFromAJAJ(data.contact_cvars, 'contact_cvars_');

      if ( contactId ) {
        $('#action_delete_contact').show();
        $('#contact_cp_title_select').val(contact['cp_title']);
        $('#contact_cp_abteilung_select').val(contact['cp_abteilung']);
      } else {
        $('#action_delete_contact').hide();
        $('#contact_cp_title_select, #contact_cp_abteilung_select').val('');
      }
      if (data.contact.disable_cp_main === 1)
        $("#contact_cp_main").prop("disabled", true);
      else
        $("#contact_cp_main").prop("disabled", false);
      if ( params.onFormSet )
        params.onFormSet();
    });

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
        if( ($mapSearchElements[i].attr('id') != prefix + 'country') && ($mapSearchElements[i].val() === '') )
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
      var query      = source_address !== '' ? 'point=' + encodeURIComponent(source_address) + '&point=' : 'point=';
      var url        = 'https://navi.graphhopper.org/?' + query + encodeURIComponent(searchString);

      window.open(url, '_blank');
      window.focus();
    };

    var render = function(widgetWrapper) {
      init();

      $widgetWrapper = $(widgetWrapper);

      $widgetWrapper
        .html('<img class="icon-map" alt="'+ kivi.t8("Powered by Graphhopper API & Openstreetmap") +'" title="'+ kivi.t8("Powered by Graphhopper API & Openstreetmap") +'" />')
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
    if (number === '')
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
//    alert("HALLO S " + source + " --T " + target + " tt D " + data);
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

  var KEY = {
    TAB:       9,
    ENTER:     13,
    SHIFT:     16,
    CTRL:      17,
    ALT:       18,
    ESCAPE:    27,
    PAGE_UP:   33,
    PAGE_DOWN: 34,
    LEFT:      37,
    UP:        38,
    RIGHT:     39,
    DOWN:      40,
  };

  ns.Picker = function($real, options) {
    var self = this;
    this.o = $.extend(true, {
      limit: 20,
      delay: 50,
      action: {
        commit_none: function(){ },
        commit_one:  function(){ $('#update_button').click(); },
        commit_many: function(){ }
      }
    }, $real.data('customer-vendor-picker-data'), options);
    this.$real              = $real;
    this.real_id            = $real.attr('id');
    this.last_real          = $real.val();
    this.$dummy             = $($real.siblings()[0]);
    this.autocomplete_open  = false;
    this.state              = this.STATES.PICKED;
    this.last_dummy         = this.$dummy.val();
    this.timer              = undefined;

    this.init();
  };

  ns.Picker.prototype = {
    CLASSES: {
      PICKED:       'customer-vendor-picker-picked',
      UNDEFINED:    'customer-vendor-picker-undefined',
    },
    ajax_data: function(term) {
      return {
        'filter.all:substr:multi::ilike': term,
        'filter.obsolete': 0,
        current:  this.$real.val(),
        type:     this.o.cv_type,
      };
    },
    set_item: function(item) {
      var self = this;
      if (item.id) {
        this.$real.val(item.id);
        // autocomplete ui has name, use the value for ajax items, which contains displayable_name
        this.$dummy.val(item.name ? item.name : item.value);
      } else {
        this.$real.val('');
        this.$dummy.val('');
      }
      this.state      = this.STATES.PICKED;
      this.last_real  = this.$real.val();
      this.last_dummy = this.$dummy.val();
      this.$real.trigger('change');

      if (this.o.fat_set_item && item.id) {
        $.ajax({
          url: 'controller.pl?action=CustomerVendor/show.json',
          data: { 'id': item.id, 'db': item.type },
          success: function(rsp) {
            self.$real.trigger('set_item:CustomerVendorPicker', rsp);
          },
        });
      } else {
        this.$real.trigger('set_item:CustomerVendorPicker', item);
      }
      this.annotate_state();
    },
    set_multi_items: function(data) {
      this.run_action(this.o.action.set_multi_items, [ data ]);
    },
    make_defined_state: function() {
      if (this.state == this.STATES.PICKED) {
        this.annotate_state();
        return true
      } else if (this.state == this.STATES.UNDEFINED && this.$dummy.val() === '')
        this.set_item({})
      else {
        this.set_item({ id: this.last_real, name: this.last_dummy })
      }
      this.annotate_state();
    },
    annotate_state: function() {
      if (this.state == this.STATES.PICKED)
        this.$dummy.removeClass(this.STATES.UNDEFINED).addClass(this.STATES.PICKED);
      else if (this.state == this.STATES.UNDEFINED && this.$dummy.val() === '')
        this.$dummy.removeClass(this.STATES.UNDEFINED).addClass(this.STATES.PICKED);
      else {
        this.$dummy.addClass(this.STATES.UNDEFINED).removeClass(this.STATES.PICKED);
      }
    },
    handle_changed_text: function(callbacks) {
      var self = this;
      $.ajax({
        url: 'controller.pl?action=CustomerVendor/ajaj_autocomplete',
        dataType: "json",
        data: $.extend( self.ajax_data(self.$dummy.val()), { prefer_exact: 1 } ),
        success: function (data) {
          if (data.length == 1) {
            self.set_item(data[0]);
            if (callbacks && callbacks.match_one) self.run_action(callbacks.match_one, [ data[0] ]);
          } else if (data.length > 1) {
            self.state = self.STATES.UNDEFINED;
            if (callbacks && callbacks.match_many) self.run_action(callbacks.match_many, [ data ]);
          } else {
            self.state = self.STATES.UNDEFINED;
            if (callbacks && callbacks.match_none) self.run_action(callbacks.match_none, [ self, self.$dummy.val() ]);
          }
          self.annotate_state();
        }
      });
    },
    handle_keydown: function(event) {
      var self = this;
      if (event.which == KEY.ENTER || event.which == KEY.TAB) {
        // if string is empty assume they want to delete
        if (self.$dummy.val() === '') {
          self.set_item({});
          return true;
        } else if (self.state == self.STATES.PICKED) {
          if (self.o.action.commit_one) {
            self.run_action(self.o.action.commit_one);
          }
          return true;
        }
        if (event.which == KEY.TAB) {
          event.preventDefault();
          self.handle_changed_text();
        }
        if (event.which == KEY.ENTER) {
          event.preventDefault();
          self.handle_changed_text({
            match_none: self.o.action.commit_none,
            match_one:  self.o.action.commit_one,
            match_many: self.o.action.commit_many
          });
          return false;
        }
      } else if (event.which == KEY.DOWN && !self.autocomplete_open) {
        var old_options = self.$dummy.autocomplete('option');
        self.$dummy.autocomplete('option', 'minLength', 0);
        self.$dummy.autocomplete('search', self.$dummy.val());
        self.$dummy.autocomplete('option', 'minLength', old_options.minLength);
      } else if ((event.which != KEY.SHIFT) && (event.which != KEY.CTRL) && (event.which != KEY.ALT)) {
        self.state = self.STATES.UNDEFINED;
      }
    },
    init: function() {
      var self = this;
      this.$dummy.autocomplete({
        source: function(req, rsp) {
          $.ajax($.extend({}, self.o, {
            url:      'controller.pl?action=CustomerVendor/ajaj_autocomplete',
            dataType: "json",
            type:     'get',
            data:     self.ajax_data(req.term),
            success:  function (data){ rsp(data) }
          }));
        },
        select: function(event, ui) {
          self.set_item(ui.item);
          if (self.o.action.commit_one) {
            self.run_action(self.o.action.commit_one);
          }
        },
        search: function(event, ui) {
          if ((event.which == KEY.SHIFT) || (event.which == KEY.CTRL) || (event.which == KEY.ALT))
            event.preventDefault();
        },
        open: function() {
          self.autocomplete_open = true;
        },
        close: function() {
          self.autocomplete_open = false;
        }
      });
      this.$dummy.keydown(function(event){ self.handle_keydown(event) });
      this.$dummy.on('paste', function(){
        setTimeout(function() {
          self.handle_changed_text();
        }, 1);
      });
      this.$dummy.blur(function(){
        window.clearTimeout(self.timer);
        self.timer = window.setTimeout(function() { self.annotate_state() }, 100);
      });
    },
    run_action: function(code, args) {
      if (typeof code === 'function')
        code.apply(this, args)
      else
        kivi.run(code, args);
    },
    clear: function() {
      this.set_item({});
    }
  };
  ns.Picker.prototype.STATES = {
    PICKED:    ns.Picker.prototype.CLASSES.PICKED,
    UNDEFINED: ns.Picker.prototype.CLASSES.UNDEFINED
  };

  ns.reinit_widgets = function() {
    kivi.run_once_for('input.customer_vendor_autocomplete', 'customer_vendor_picker', function(elt) {
      if (!$(elt).data('customer_vendor_picker'))
        $(elt).data('customer_vendor_picker', new kivi.CustomerVendor.Picker($(elt)));
    });

    $('#cv_phone,#shipto_shiptophone,#additional_billing_address_phone,#contact_cp_phone1,#contact_cp_phone2,#contact_cp_mobile1,#contact_cp_mobile2').each(function(idx, elt) {
      kivi.CustomerVendor.init_dial_action($(elt));
    });
  }

  ns.init = function() {
    ns.reinit_widgets();
  }

  ns.get_price_report = function(target, source, data) {
    $.ajax({
      url:        source,
      success:    function (rsp) {
        $(target).html(rsp);
        $(target).find('a.report-generator-header-link').click(function(event){ ns.price_report_redirect_event(event, target) });
      },
    });
  };

  ns.price_report_redirect_event = function (event, target) {
    event.preventDefault();
    ns.get_price_report(target, event.target + '');
  };

  ns.price_list_init = function () {
    $("#customer_vendor_tabs").on('tabsbeforeactivate', function(event, ui){
      if (ui.newPanel.attr('id') == 'price_list') {
        ns.get_price_report('#price_list', "controller.pl?action=CustomerVendor/ajax_list_prices&id=" + $('#cv_id').val() + "&db=" + $('#db').val() + "&callback=" + $('#callback').val());
      }
      return 1;
    });

    $("#customer_vendor_tabs").on('tabscreate', function(event, ui){
      if (ui.panel.attr('id') == 'price_list') {
        ns.get_price_report('#price_list', "controller.pl?action=CustomerVendor/ajax_list_prices&id=" + $('#cv_id').val() + "&db=" + $('#db').val() + "&callback=" + $('#callback').val());
      }
      return 1;
    });
  }

  this.check_cv = function(cv_id, input_element_id, cv_type) {
    if (cv_id === '' || $(input_element_id).val() === '') {
      if (cv_type === 'customer') {
        alert(kivi.t8('Please select a customer.'));
      } else {
        alert(kivi.t8('Please select a vendor.'));
      }
      return false;
    }
    return true;
  };

  this.show_cv_details_dialog = function(id_selector, cv_type) {

    const input_element_id = `${id_selector}_name`;
    const cv_id = $(id_selector).val();

    if (!this.check_cv(cv_id, input_element_id, cv_type)) return;

    kivi.popup_dialog({
      url:    'controller.pl',
      data:   { action: 'CustomerVendor/show_customer_vendor_details_dialog',
                type  : $('#type').val(),
                cv    : cv_type,
                cv_id : cv_id
              },
      id:     'jq_customer_vendor_details_dialog',
      dialog: {
        title:  cv_type === 'customer' ? kivi.t8('Customer details') : kivi.t8('Vendor details'),
        width:  800,
        height: 650
      }
    });
    return true;
  };

  this.contacts_update_email_fields = function() {
    $('.update_email').each(function(idx, elt) {
      let $link = $('#' + $(elt).attr('id') + '_link');
      if ($(elt).val() !== '') {
        $link.attr('href', 'mailto:' + $(elt).val());
        $link.show();
      } else {
        $link.hide();
      }
    });
  };

  this.open_customervendor_tab = function(id_selector, cv_type) {
    const input_element_id = `${id_selector}_name`;
    const cv_id = $(id_selector).val();

    if (!this.check_cv(cv_id, input_element_id, cv_type)) return;

    window.open("controller.pl?action=CustomerVendor/edit&db=" + encodeURIComponent(cv_type) + "&id=" + encodeURIComponent(cv_id), '_blank');
  };

  $(function(){
    ns.init();
    ns.price_list_init();
  });
});
