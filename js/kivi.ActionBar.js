namespace('kivi', function(k){
  'use strict';

   k.ActionBarAction = function(e) {
     var data = $(e).data('action');

     if (data.disabled)
       $(e).addClass('layout-actionbar-action-disabled');
     // dispatch as needed
     if (data.submit) {
       var form   = data.submit[0];
       var params = data.submit[1];
       $(e).click(function(event) {
         var $hidden, key, func, check;
         if (data.disabled) return;
         if (data.confirm && !confirm(data.confirm)) return;
         if (data.checks) {
           for (var i=0; i < data.checks.length; i++) {
             check = data.checks[i];
             func = kivi.get_function_by_name(check);
             if (!func) console.log('Cannot find check function: ' + check);
             if (!func()) return;
           }
         }
         for (key in params) {
           $hidden = $('<input type=hidden>')
           $hidden.attr('name', key)
           $hidden.attr('value', params[key])
           $(form).append($hidden)
         }
         $(form).submit()
       })
     } else if (data.function) {
       // TODO: what to do with templated calls
       $(e).click(function(event) {
         var func;
         if (data.disabled) return;
         if (data.confirm && !confirm(data.confirm)) return;
         if (data.checks) {
           for (var i=0; i < data.checks.length; i++) {
             check = data.checks[i];
             func = kivi.get_function_by_name(check);
             if (!func) console.log('Cannot find check function: ' + check);
             if (!func()) return;
           }
         }
         func = kivi.get_function_by_name(data.function[0]);
         func.apply(document, data.function.slice(1))
       });
     }
   }
});

$(function(){
  $('div.layout-actionbar .layout-actionbar-action').each(function(_, e) {
    kivi.ActionBarAction(e);
  });
});
