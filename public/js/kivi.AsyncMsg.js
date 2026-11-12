namespace("kivi.AsyncMsg", function(ns) {
  "use strict";

  ns.last_msg_id = 0;
  ns.ami_connected = false;
  ns.ws_connected = false;

  ns.connect_ws = function() {
    const socket = new WebSocket(kivi.myconfig.frontend_websocket_location);


    socket.addEventListener("message", (event) => {
      if (!event.data || event.data.length == 0) return;
      const data = JSON.parse(event.data);
      ns.ami_connected = data.ami_connected;
      ns.update_status_indicator();

      data.redacted_event_ids.forEach((id) => kivi.Flash.remove_msg_by_id(id));
      for (let ev of data.events) {
        if (ev.id <= ns.last_msg_id) continue;
        const message = ev.subject;
        const details = ev.body;
        const timestamp = ev.ts_fmt;
        kivi.Flash.display_flash(ev.msg_type, message, details, timestamp, ev.id);
      }

      if (ns.last_msg_id < data.last_msg_id)
        ns.last_msg_id = data.last_msg_id;
    });
    socket.addEventListener("open", (event) => {
      ns.ws_connected = true;
      ns.update_status_indicator();
    });
    socket.addEventListener("error", (error) => {
      console.error('WebSocket error:', error);
      socket.close();
    });
    socket.addEventListener("close", (event) => {
      ns.ws_connected = false;
      ns.update_status_indicator();
      const delay_ms = 15000;
      setTimeout(function() {
          ns.connect_ws();
      }, delay_ms);
    });
  };

  ns.update_status_indicator = function() {
    let css = '';
    let msg = '';
    if (!ns.ws_connected) {
      css = ''; // white
      msg = kivi.t8('Show/Hide flash messages');

    } else if (!ns.ami_connected) {
      css = 'brightness(0.5) sepia(1) hue-rotate(0deg) saturate(15)'; // dark red
      msg = kivi.t8('The message broker is available, but it has no AMI connection to the phone system');

    } else {
      css = 'brightness(0.5) sepia(1) hue-rotate(90deg) saturate(15)'; // ligh green
      msg = kivi.t8('Show/Hide flash messages');
    }
    console.log('AsyncMessage status WS / AMI connected', ns.ws_connected, ns.ami_connected);

    $('#flash-toggle')[0].title                   = msg;
    $('.layout-flash-toggle img')[0].style.filter = css;
  };
});

$(function() {
  "use strict";
  kivi.AsyncMsg.connect_ws();
});
