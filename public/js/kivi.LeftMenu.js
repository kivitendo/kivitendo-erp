namespace('kivi.LeftMenu', function(ns) {
  'use strict';
  ns.init = function(sections) {
    sections.forEach(function(b,i){
      var a=$('<a class="ml">').append($('<span class="mii ms">').append($('<div>').addClass(b[3])),$('<span class="mic">').append(b[0]));
      if(b[5])a.attr('href', b[5]);
      if(b[6])a.attr('target', b[6]);
      $('#html-menu').append($('<div class="mi">').addClass(b[4]).addClass(b[1]).attr('id','mi'+b[2]).append(a))
    });
    $('#html-menu div.i, #html-menu div.sm').not('[id^='+$.cookie('html-menu-selection')+'_]').hide();
    $('#html-menu div.m#'+$.cookie('html-menu-selection')).addClass('menu-open');
    $('#html-menu div.m').each(function(){
      $(this).click(function(){
        $.cookie('html-menu-selection',$(this).attr('id'));
        $('#html-menu div.mi').not('div.m').not('[id^='+$(this).attr('id')+'_]').hide();
        $('#html-menu div.mi[id^='+$(this).attr('id')+'_]').toggle();
        $('#html-menu div.m').not('[id^='+$(this).attr('id')+']').removeClass('menu-open');
        $(this).toggleClass('menu-open');
      });
    });
  };
});
