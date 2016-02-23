namespace('kivi', function(k){
  k.QuickSearch = function($real, options) {
    if ($real.data("quick_search"))
      return $real.data("quick_search");

    var KEY = {
      ENTER:     13,
    };
    var o = $.extend({
      limit: 20,
      delay: 50,
    }, options);

    function send_query(action, term, id, success) {
      var data = { module: o.module };
      if (term != undefined) data.term = term;
      if (id   != undefined) data.id   = id;
      $.ajax($.extend(o, {
        url:      'controller.pl?action=TopQuickSearch/' + action,
        dataType: "json",
        data:     data,
        success:  success
      }));
    }

    function submit_search(term) {
      send_query('do_search', term, undefined, kivi.eval_json_result);
    }

    $real.autocomplete({
      source: function(req, rsp) {
        send_query('query_autocomplete', req.term, undefined, function (data){ rsp(data) });
      },
      select: function(event, ui) {
        send_query('select_autocomplete', undefined, ui.item.id, kivi.eval_json_result);
      },
    });
    $real.keydown(function(event){
      if (event.which == KEY.ENTER) {
        if ($real.val() != '') {
          submit_search($real.val());
        }
      }
    });

    $real.data('quick_search', {});
  }
});

$(function(){
  $('input[id^=top-quick-search]').each(function(_,e){
    kivi.QuickSearch($(e), { module: $(e).attr('module') })
  })
})
