namespace("kivi", function(ns) {
  ns._locale = {};

  ns.t8 = function(text, params) {
    var text = ns._locale[text] || text;

    if( Object.prototype.toString.call( params ) === '[object Array]' ) {
      var len = params.length;

      for(var i=0; i<len; ++i) {
        var key = i + 1;
        var value = params[i];
        text = text.split("#"+ key).join(value);
      }
    }
    else if( typeof params == 'object' ) {
      for(var key in params) {
        var value = params[key];
        text = text.split("#{"+ key +"}").join(value);
      }
    }

    return text;
  };

  ns.setupLocale = function(locale) {
    ns._locale = locale;
  };

  ns.reinit_widgets = function() {
    $('.datepicker').each(function() {
      $(this).datepicker();
    });

    if (ns.PartPicker)
      $('input.part_autocomplete').each(function(idx, elt){
        kivi.PartPicker($(elt));
      });
  };
});

kivi = namespace('kivi');
