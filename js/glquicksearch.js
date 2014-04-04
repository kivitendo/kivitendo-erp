$(function() {
  $( "#glquicksearch" ).autocomplete({
    source: "controller.pl?action=GL/quicksearch",
    minLength: 3,
    select: function(event, ui) {
           var url = ui.item.url;
           if(url != '#') {
               location.href = url;
           }
       },
    html: false,
    autoFocus: true
  });
});
