/*
 * jQuery SelectAll plugin 1.1
 *
 * Copyright (c) 2009 Sven Schöling
 */

;(function($) {

$.fn.extend({
  checkall: function(target) {
    var saved_this = this;
    return $(this).click(function() {
      $(target).each(function() {
        $(this).attr('checked', $(saved_this).attr('checked'));
      });
    });
  }
});

})(jQuery);
