namespace('kivi', function(k){
  'use strict';

  var CLASSES = {
    disabled: 'layout-actionbar-action-disabled'
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
         if ($(e).hasClass(CLASSES.disabled)) return;
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
    kivi.ActionBarAction(e);
  });
});
