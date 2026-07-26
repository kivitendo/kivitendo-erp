namespace("kivi.AsyncMsg", function(ns) {
  "use strict";

  ns.last_msg_id = 0;

  ns.connect_ws = function() {
    const socket = new WebSocket(kivi.myconfig.frontend_websocket_location
      + '?last_msg_id=' + ns.last_msg_id);

    socket.addEventListener("message", (event) => {
      if (!event.data || event.data.length == 0) return;
      const data = JSON.parse(event.data);

      data.redacted_event_ids.forEach((id) => kivi.Flash.remove_msg_by_id(id));
      for (let ev of data.events) {
        const message = ev.subject;
        const details = ev.body;
        const timestamp = ev.ts_fmt;
        kivi.Flash.display_flash(ev.msg_type, message, details, timestamp, ev.id);
      }

      ns.last_msg_id = data.last_msg_id;
    });
    socket.addEventListener("open", (event) => {
      $('.layout-flash-toggle img')[0].style.filter = 'brightness(0.5) sepia(1) hue-rotate(90deg) saturate(15)';
    });
    socket.addEventListener("error", (error) => {
      console.error('WebSocket error:', error);
      socket.close();
    });
    socket.addEventListener("close", (event) => {
      $('.layout-flash-toggle img')[0].style.filter = '';
      const delay_ms = 15000;
      setTimeout(function() {
          ns.connect_ws();
      }, delay_ms);
    });
  };
});

$(function() {
  "use strict";
  kivi.AsyncMsg.connect_ws();
});
