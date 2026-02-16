function load_layout(baseURL){
  $.ajax({
    url: baseURL + 'controller.pl?action=Layout/empty&format=json',
    method: 'GET',
    dataType: 'json',
    success: function (data) {
      if (data["stylesheets"]) {
        $.each(data["stylesheets"], function(i, e){
          $('head').append('<link rel="stylesheet" href="' + baseURL + e + '" type="text/css" title="Stylesheet">');
        });
      }
      if (data["stylesheets_inline"] && data["stylesheets_inline"].size) {
        var style = "<style type='text/css'>";
        $.each(data["stylesheets_inline"], function(i, e){
          style += e;
        });
        style += '</style>';
        $('head').append(style);
      }
      if (data["start_content"]) {
        $('body').wrapInner(data["start_content"]);
      }
      if (data["pre_content"]) {
        $('body').prepend(data["pre_content"]);
      }
      if (data["post_content"]) {
        $('body').append(data["post_content"]);
      }
      if (data["javascripts"]) {
        $.each(data["javascripts"], function(i, e){
          $('head').append('<script type="text/javascript" src="' + baseURL + e + '">');
        });
      }
      if (data["javascripts_inline"]) {
        var script = "<script type='text/javascript'>";
        $.each(data["javascripts_inline"], function(i, e){
          script += e;
        });
        script += '</script>';
        $('head').append(script);
      }
    }
  });
}
