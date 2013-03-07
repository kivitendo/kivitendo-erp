namespace("kivi", function(ns) {

  ns._localeLang = false;
  ns._locales = {};

  ns.t8 = function(text, params) {
    if( ns._localeLang ) {
      if( !ns._locales[ns._localeLang] ) {
        jQuery.ajax({
          url: "js/locale/"+ ns._localeLang +".js",
          async: false,
          dataType: "json",
          success: function(res) {
            ns._locales[ns._localeLang] = res;
          },
          error: function(xhr, textStatus, errorThrown) {
            alert(textStatus +": "+ errorThrown);
          },
        });
      }

      text = ns._locales[ns._localeLang][text] || text;
    }

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

  ns.initLocale = function(localeLang) {
    ns._localeLang = localeLang;
  };

});
