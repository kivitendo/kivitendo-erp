namespace('kivi', function(k){
  'use strict';

  var CLASSES = {
    active:   'active',
    actionbar: 'layout-actionbar',
    disabled: 'layout-actionbar-action-disabled',
    action:   'layout-actionbar-action',
    combobox: 'layout-actionbar-combobox',
  }

  k.ActionBarCombobox = function(e) {
    this.combobox = e;
    this.head     = e.childNodes[0];
    this.toggle   = this.head.childNodes[1];
    this.list     = e.childNodes[0];
    this.init();
  }

  k.ActionBarCombobox.prototype = {
    init: function() {
      var obj = this;
      $(obj.toggle).on('click', function(event){
        $('div.' + CLASSES.combobox + '[id!=' + obj.combobox.id + ']').removeClass(CLASSES.active);
        $(obj.combobox).toggleClass(CLASSES.active);
        event.stopPropagation();
      });
    }
  };

  k.ActionBarAccesskeys = {
    known_keys: {
     'enter': 13,
     'esc': 27,
    },
    actions: {},
    bound_targets: {},

    add_accesskey: function (target, keystring, action) {
      if (target === undefined) {
        target = 'document';
      }

      var normalized = $.map(String.prototype.split.call(keystring, '+'), function(val, i) {
        console.log(keystring)
        switch (val) {
          case 'ctrl':
          case 'alt':  return val;
          case 'enter': return 13;
          default:
            if (val.length == 1) {
              return val.charChodeAt(0)
            } else if (val % 1 === 0) {
              return val;
            } else {
              console.log('can not normalize access key token: ' + val);
            }
        }
      }).join('+');

      if (!(target in this.actions))
        this.actions[target] = {};
      this.actions[target][normalized] = action;
    },

    bind_targets: function(){
      for (var target in this.actions) {
        if (target in this.bound_targets) continue;
        $(target).on('keypress', null, { 'target': target }, this.handle_accesskey);
        this.bound_targets[target] = 1;
      }
    },

    handle_accesskey: function(e,t) {
      var target = e.data.target;
      var key = e.which;
      var accesskey = '';
      if (e.ctrlKey) accesskey += 'crtl+'
      if (e.altKey)  accesskey += 'alt+'
      accesskey += e.which;

      // special case. HTML elements that make legitimate use of enter will also trigger the enter accesskey.
      // so. if accesskey is '13' and the event source is one of these (currently only textareas & combo boxes) ignore it.
      // higher level widgets will usually prevent their key events from bubbling if used.
      if (   (accesskey == 13)
          && (   (e.target.tagName == 'TEXTAREA')
              || (e.target.tagName == 'SELECT')))
        return true;

      if ((target in k.ActionBarAccesskeys.actions) && (accesskey in k.ActionBarAccesskeys.actions[target])) {
        e.stopPropagation();
        k.ActionBarAccesskeys.actions[target][accesskey].click();

        // and another special case.
        // if the form contains submit buttons the default action will click them instead.
        // prevent that
        if (accesskey == 13) return false;
      }
      return true;
    }
  };

  k.ActionBarAction = function(e) {
    var data = $(e).data('action');
    if (undefined === data) return;

    if (data.disabled) {
      $(e).addClass(CLASSES.disabled);
      if (!data.tooltip && (data.disabled != '1'))
        data.tooltip = data.disabled;
    }

    if (data.accesskey) {
      if (data.submit) {
        k.ActionBarAccesskeys.add_accesskey(data.submit[0], data.accesskey, $(e));
      }
      if (data.call) {
        k.ActionBarAccesskeys.add_accesskey(undefined, data.accesskey, $(e));
      }
    }

    if (data.tooltip) {
      $(e).tooltipster({ content: data.tooltip, theme: 'tooltipster-light' });
    }

    if (data.call || data.submit) {
      $(e).click(function(event) {
        var $hidden, key, func, check;
        if ($(e).hasClass(CLASSES.disabled)) {
          event.stopPropagation();
          return;
        }
        if (data.checks) {
          for (var i=0; i < data.checks.length; i++) {
            check = data.checks[i];
            func = kivi.get_function_by_name(check);
            if (!func) console.log('Cannot find check function: ' + check);
            if (!func()) return;
          }
        }
        if (data.confirm && !confirm(data.confirm)) return;
        if (data.call) {
          func = kivi.get_function_by_name(data.call[0]);
          func.apply(document, data.call.slice(1))
        }
        if (data.submit) {
          var form   = data.submit[0];
          var params = data.submit[1];
          for (key in params) {
            $hidden = $('<input type=hidden>')
            $hidden.attr('name', key)
            $hidden.attr('value', params[key])
            $(form).append($hidden)
          }
          $(form).submit();
        }
      });
    }
  }
});

$(function(){
  $('div.layout-actionbar .layout-actionbar-action').each(function(_, e) {
    kivi.ActionBarAction(e)
  });
  $('div.layout-actionbar-combobox').each(function(_, e) {
    $(e).data('combobox', new kivi.ActionBarCombobox(e));
  });
  $(document).click(function() {
    $('div.layout-actionbar-combobox').removeClass('active');
  });
  kivi.ActionBarAccesskeys.bind_targets();
});
