jQuery.download = function(url, data, method) {
  //url and data options required
  if (!url || !data)
    return;

  //data can be string of parameters or array/object
  data = typeof data == 'string' ? data : jQuery.param(data);
  //split params into form inputs
  var form = jQuery('<form action="'+ url +'" method="'+ (method||'post') +'"></form>');
  jQuery.each(data.split('&'), function(){
    var pair  = this.split('=');
    var input = jQuery('<input type="hidden"/>');
    input.attr('name', decodeURIComponent(pair[0]));
    input.val(decodeURIComponent(pair[1]));
    input.appendTo(form);
  });
  //send request
  form.appendTo('body').submit().remove();
};
