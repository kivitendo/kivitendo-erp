namespace('kivi.Contact', function(ns) {
  ns.check_contact = function() {
    return kivi.Validator.validate_all('#form');
  };

  ns.on_add_cv_vendor   = function() { ns.on_add_cv('vendor'); };
  ns.on_add_cv_customer = function() { ns.on_add_cv('customer'); };

  ns.on_add_cv = function(db) {
    let cv_id = $('#add_' + db + '_id').val();
    if (!cv_id)
      return;

    var data = $('#form').serializeArray();
    data.push({ name: 'action', value: 'Contact/add_cv' },
              { name: 'cv_db', value: db },
              { name: 'cv_id', value: cv_id });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.on_add_contact = function(db) {
    if (!$('#add_contact_id').val())
      return;
    var data = [];
    data.push({ name: 'action', value: 'Contact/add_contact' },
              { name: 'cv_db',  value: $('[name=db]').val() },
              { name: 'cv_id',  value: $('#cv_id').val() },
              { name: 'id',     value: $('#add_contact_id').val() });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.detach_contact_or_cv = function(clicked) {
    var row = $(clicked).parents('tr').first();
    $(row).remove();
  };

  ns.set_main_contact = function(clicked) {
    let inputs = $(clicked).parents('table').first().find('[name="linked_contacts[].main"]');
    inputs.map((index, el) => {
      if (el != clicked)
        $(el).val(0);
    });
  };

  ns.save = function() {
    if (!ns.check_contact()) return;

    var data = $('#form').serializeArray();
    data.push({ name: 'action', value: 'Contact/save' });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.delete_contact = function() {
    var data = $('#form').serializeArray();
    data.push({ name: 'action', value: 'Contact/delete' });

    $.post("controller.pl", data, kivi.eval_json_result);
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
    }, $real.data('contact-picker-data'), options);
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
      PICKED:       'contact-picker-picked',
      UNDEFINED:    'contact-picker-undefined',
    },
    ajax_data: function(term) {
      return {
        'filter.all:substr:multi::ilike': term,
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
          url: 'controller.pl?action=Contact/show.json',
          data: { 'id': item.id, 'db': item.type },
          success: function(rsp) {
            self.$real.trigger('set_item:ContactPicker', rsp);
          },
        });
      } else {
        this.$real.trigger('set_item:ContactPicker', item);
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
        url: 'controller.pl?action=Contact/ajaj_autocomplete',
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
            url:      'controller.pl?action=Contact/ajaj_autocomplete',
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
    kivi.run_once_for('input.contact_autocomplete', 'contact_picker', function(elt) {
      if (!$(elt).data('contact_picker'))
        $(elt).data('contact_picker', new kivi.Contact.Picker($(elt)));
    });
  }

  ns.init = function() {
    ns.reinit_widgets();
  }

  $(function() {
    ns.init();
  });
});
