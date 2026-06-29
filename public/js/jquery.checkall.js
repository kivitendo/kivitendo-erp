/*
 * jQuery SelectAll plugin 1.1
 *
 * Copyright (c) 2009 Sven Schöling
 */

;(function($) {

$.fn.extend({
  checkall: function(target, property, inverted) {
    if (property == null)
      property = 'checked';
    return $(this).click(function() {
      $(target).prop(property, inverted ? !$(this).prop('checked') : $(this).prop('checked'));
    });
  }
});

})(jQuery);
