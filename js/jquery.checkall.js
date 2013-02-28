/*
 * jQuery SelectAll plugin 1.1
 *
 * Copyright (c) 2009 Sven Schöling
 */

;(function($) {

$.fn.extend({
  checkall: function(target, property) {
    if (property == null)
      property = 'checked';
    return $(this).click(function() {
      $(target).prop(property, $(this).prop('checked'));
    });
  }
});

})(jQuery);
