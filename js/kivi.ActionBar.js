namespace('kivi', function(k){
  'use strict';

   k.ActionBarAction = function(e) {
     var data = $(e).data('action');
     // dispatch as needed
     if (data.submit) {
       var form   = data.submit[0];
       var params = data.submit[1];
       $(e).click(function(event) {
         var $hidden, key;
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
       console.log(data.function)
       $(e).click(function(event) {
         var func = kivi.get_function_by_name(data.function[0]);
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
