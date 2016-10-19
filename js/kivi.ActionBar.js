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
        $(obj.combobox).toggleClass(CLASSES.active);
        event.stopPropagation();
      });
    }
  }

  k.ActionBarAction = function(e) {
    var data = $(e).data('action');
    if (undefined === data) return;

    if (data.disabled) {
      $(e).addClass(CLASSES.disabled);
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
});
