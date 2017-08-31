namespace('kivi.ActionBar', function(k){
  'use strict';

  var CLASSES = {
    active:   'active',
    actionbar: 'layout-actionbar',
    disabled: 'layout-actionbar-action-disabled',
    action:   'layout-actionbar-action',
    combobox: 'layout-actionbar-combobox',
    default:  'layout-actionbar-default-action',
  };

  k.Combobox = function(e) {
    this.combobox  = e;
    this.head      = e.childNodes[0];
    this.topAction = this.head.childNodes[0];
    this.toggle    = this.head.childNodes[1];
    this.list      = e.childNodes[0];
    this.init();
  };

  k.Combobox.prototype = {
    init: function() {
      var obj     = this;
      var toggler = function(event){
        $('div.' + CLASSES.combobox + '[id!=' + obj.combobox.id + ']').removeClass(CLASSES.active);
        $(obj.combobox).toggleClass(CLASSES.active);
        event.stopPropagation();
      };

      $(obj.toggle).on('click', toggler);

      var data = $(this.topAction).data('action') || {};
      if (!data.call && !data.submit)
        $(this.topAction).on('click', toggler);
    }
  };

  k.Accesskeys = {
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
        switch (val) {
          case 'ctrl':
          case 'alt':  return val;
          case 'enter': return 13;
          default:
            if (val.length == 1) {
              return val.charChodeAt(0);
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

      if ((target in kivi.ActionBar.Accesskeys.actions) && (accesskey in kivi.ActionBar.Accesskeys.actions[target])) {
        e.stopPropagation();
        kivi.ActionBar.Accesskeys.actions[target][accesskey].click();

        // and another special case.
        // if the form contains submit buttons the default action will click them instead.
        // prevent that
        if (accesskey == 13) return false;
      }
      return true;
    }
  };

  k.removeTooltip = function($e) {
    if ($e.hasClass('tooltipstered'))
      $e.tooltipster('destroy');
    $e.prop('title', '');
  };

  k.setTooltip = function($e, tooltip) {
    if ($e.hasClass('tooltipstered'))
      $e.tooltipster('content', tooltip);
    else
      $e.tooltipster({ content: tooltip, theme: 'tooltipster-light' });
  };

  k.setDisabled = function($e, tooltip) {
    var data = $e.data('action');

    $e.addClass(CLASSES.disabled);

    if (tooltip && (tooltip != '1'))
      kivi.ActionBar.setTooltip($e, tooltip);
    else
      kivi.ActionBar.removeTooltip($e);
  };

  k.setEnabled = function($e) {
    var data = $e.data('action');

    $e.removeClass(CLASSES.disabled);

    if (data.tooltip)
      kivi.ActionBar.setTooltip($e, data.tooltip);
    else
      kivi.ActionBar.removeTooltip($e);
  };

  k.Action = function(e) {
    var $e       = $(e);
    var instance = $e.data('instance');
    if (instance)
      return instance;

    var data = $e.data('action');
    if (undefined === data) return;

    data.originalTooltip = data.tooltip;

    if (data.disabled && (data.disabled != '0'))
      kivi.ActionBar.setDisabled($e, data.disabled);

    else if (data.tooltip)
      kivi.ActionBar.setTooltip($e, data.tooltip);

    if (data.accesskey) {
      if (data.submit) {
        kivi.ActionBar.Accesskeys.add_accesskey(data.submit[0], data.accesskey, $e);
      }
      if (data.call) {
        kivi.ActionBar.Accesskeys.add_accesskey('body', data.accesskey, $e);
      }
      if (data.accesskey == 'enter') {
        $e.addClass(CLASSES.default);
      }
    }

    if (data.call || data.submit || data.link) {
      $e.click(function(event) {
        var $hidden, key, func, check;
        if ($e.hasClass(CLASSES.disabled)) {
          event.stopPropagation();
          return;
        }
        if (data.checks) {
          for (var i=0; i < data.checks.length; i++) {
            check = data.checks[i];
            if (check.constructor !== Array)
              check = [ check ];
            func = kivi.get_function_by_name(check[0]);
            if (!func)
              console.log('Cannot find check function: ' + check);
            if (!func.apply(document, check.slice(1)))
              return;
          }
        }
        if (data.confirm && !confirm(data.confirm)) return;
        if (data.call) {
          func = kivi.get_function_by_name(data.call[0]);
          func.apply(document, data.call.slice(1));
        }
        if (data.submit) {
          var form   = data.submit[0];
          var params = data.submit[1];
          for (key in params) {
            $('[name=' + key + ']').remove();
            $hidden = $('<input type=hidden>');
            $hidden.attr('name', key);
            $hidden.attr('value', params[key]);
            $(form).append($hidden);
          }
          $(form).submit();
        }
        if (data.link) {
          window.location.href = data.link;
        }
        if ((data.only_once !== undefined) && (data.only_once !== 0)) {
          $e.addClass(CLASSES.disabled);
          $e.tooltipster({ content: kivi.t8("The action can only be executed once."), theme: 'tooltipster-light' });
        }
      });
    }

    instance = {
      removeTooltip: function()        { kivi.ActionBar.removeTooltip($e); },
      setTooltip:    function(tooltip) { kivi.ActionBar.setTooltip($e, tooltip); },
      disable:       function(tooltip) { kivi.ActionBar.setDisabled($e, tooltip); },
      enable:        function()        { kivi.ActionBar.setEnabled($e, $e.data('action').tooltip); },
    };

    $e.data('instance', instance);

    return instance;
  };
});

$(function(){
  $('div.layout-actionbar .layout-actionbar-action').each(function(_, e) {
    kivi.ActionBar.Action(e);
  });
  $('div.layout-actionbar-combobox').each(function(_, e) {
    $(e).data('combobox', new kivi.ActionBar.Combobox(e));
  });
  $(document).click(function() {
    $('div.layout-actionbar-combobox').removeClass('active');
  });
  kivi.ActionBar.Accesskeys.bind_targets();
});
