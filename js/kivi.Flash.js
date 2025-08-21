namespace("kivi.Flash", function(ns) {
  "use strict";

  ns.type_to_title = {
    error:   kivi.t8('Error'),
    warning: kivi.t8('Warning'),
    info:    kivi.t8('Information'),
    ok:      kivi.t8('Ok')
  };

  ns.display_flash = function(type, message, details, timestamp) {
    if (kivi.Materialize)
      return kivi.Materialize.display_flash(type, message, details, timestamp);


    let $dom = $('<div>');
    $dom.addClass('layout-flash-' + type);
    $dom.addClass('layout-flash-message');

    let $header = $('<div>');
    $header.addClass('layout-flash-header');

    let $remove = $('<span>✘</span>');
    $remove.addClass('layout-flash-remove').addClass('cursor-pointer');
    $remove.attr('alt', kivi.t8('Close Flash'));
    $header.append($remove);

    if (timestamp === undefined) {
      timestamp = new Date();
    } else if (timestamp > 0) {
      timestamp = new Date(timestamp * 1000);
    }

    let $time = $('<span>');
    $time.addClass('layout-flash-timestamp');
    $time.text(kivi.format_time(timestamp));
    $header.append($time);

    let $type = $('<span>');
    $type.addClass('layout-flash-type');
    $type.text(ns.type_to_title[type]);
    $header.append($type);

    let $body = $('<div>');
    $body.addClass('layout-flash-body');

    if (message !== undefined && message !== null) {
      let $message =  $('<span>');
      $message.addClass('layout-flash-content');
      $message.html(message);
      $body.append($message);
    }

    if (details !== undefined && details !== null) {
      let $details =  $('<span>');
      $details.addClass('layout-flash-details');
      $details.html(details);
      $body.append($details);
    }

    $dom.append($header);
    $dom.append($body);

    $("#layout_flash_container").append($dom);

    // fadeout after 1min
    $dom.delay(60000).fadeOut('slow');

    ns.show();
  };

  ns.display_flash_detail = function(type, message) {
    $('#flash_' + type + '_disp').show();
  };

  ns.clear_flash = function(category, timeout) {
    if (kivi.Materialize)
      return kivi.Materialize.clear_flash(category, timeout);

    if (timeout === undefined) {
      ns.clear_flash_now(category);
    } else {
      window.setTimeout(function(){
        ns.clear_flash_now(category);
      }, timeout);
    }
  };

  ns.clear_flash_now = function(category) {
    if (category) {
      $('div.layout-flash-' + category).remove();
    } else {
      $('div.layout-flash-message').remove();
    }
  };

  ns.remove_entry = function(e) {
    $(e.target).closest('div.layout-flash-message').remove();
  };

  ns.toggle = function() {
    $('#layout_flash_container').toggle();
  };
  ns.show = function() {
    if (kivi.Materialize) return; // materialize doesn't have a show/hide all

    $('#layout_flash_container').show();
  };
  ns.hide = function() {
    if (kivi.Materialize) return; // materialize doesn't have a show/hide all

    $('#layout_flash_container').hide();
  };
  ns.reload_flash = function() {
    $.get("controller.pl", { action: "Flash/reload" }, kivi.eval_json_result);
  };

  ns.reinit_widgets = function() {

  };
});

$(function() {
  "use strict";
  // dispatch to kivi.Flash for compatibility
  kivi.display_flash        = kivi.Flash.display_flash;
  kivi.display_flash_detail = kivi.Flash.display_flash_detail;
  kivi.empty_flash          = kivi.Flash.empty_flash;
  kivi.clear_flash          = kivi.Flash.clear_flash;

  $('.layout-flash-toggle').click(kivi.Flash.toggle);
  $('#layout_flash_container').on('click', '.layout-flash-remove', kivi.Flash.remove_entry);
});
