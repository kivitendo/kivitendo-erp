var namespace = (function() {
  var namespace = function(nsString, callback) {
    var nsParts = nsString.split(namespace.namespaceDelimiter);

    var ns = namespace.root;

    var len = nsParts.length;
    for(var i=0; i<len; ++i)
    {
      if( !ns[nsParts[i]] )
        ns[nsParts[i]] = {__namespaceAutoCreated: true};

      ns = ns[nsParts[i]];
    }

    if( callback )
    {
      var nsExt = callback.call(ns, ns);

      if( nsExt )
      {
        if( !ns )
          ns = {};

        for(var key in nsExt)
          ns[key] = nsExt[key];
      }

      ns.__namespaceAutoCreated = false;
    }
    else if( namespace.loadNamespace && ns.__namespaceAutoCreated )
    {
      var url;

      var len = namespace.namespaceLocations.length;
      for(var i=0; i<len; ++i)
      {
        var entry = namespace.namespaceLocations[i];
        if( nsString.indexOf(entry.namespace) === 0 )
        {
          url = entry.location;
          break;
        }
      }

      url += "/"+ nsString +".js";

      jQuery.ajax({
        url: url,
        async: false,
        dataType: "text",
        success: function(res) {
          eval(res);
          /*
          var script = window.document.createElement("script");
          script.type = "text/javascript";
          script.text = res;
          window.document.body.appendChild(script);
          */
        },
        error: function(xhr, textStatus, errorThrown) {
          alert(textStatus +": "+ errorThrown);
        },
      });
    }

    return ns;
  };

  return namespace;
})();

window.namespaceRoot = {};
namespace.root = window.namespaceRoot;
namespace.namespaceDelimiter = ".";
namespace.namespaceLocations = [{namespace: "", location: "js"}];
namespace.loadNamespace = true;
