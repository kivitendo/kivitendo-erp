namespace("kivi.AsyncMsg", function(ns) {
  "use strict";

  //ns.seqno = 0;

  ns.connect_ws = function() {
    const socket = new WebSocket("ws://localhost:8081/ws");
    undefined
    socket.addEventListener("message", (event) => {
      console.log("Message from server ", event.data);
      //document.body.append(document.createTextNode(event.data));
      if (!event.data || event.data.length == 0) return;
      const data = JSON.parse(event.data);

      data.redacted_event_ids.forEach((id) => kivi.Flash.remove_msg_by_id(id));
      for (let ev of data.events) {
        const message = ev.subject;
        const details = ev.body;
        const timestamp = ev.ts_fmt;
        kivi.Flash.display_flash('info', message, details, timestamp, ev.id);
      }
    });
    socket.addEventListener("open", (event) => {
      socket.send("Hello Server!");
    });
  };

  /*ns.pollServer = async function() {
    try {
      const response = await fetch('controller.pl?action=AsyncEvent/poll_events&seqno=' + ns.seqno);
      const data = await response.json();
      ns.seqno = data.next_seqno;
      data.redacted_event_ids.forEach((id) => kivi.Flash.remove_msg_by_id(id));
      for (let ev of data.events) {
        const message = ev.subject;
        const details = ev.body;
        const timestamp = ev.ts_fmt;
        kivi.Flash.display_flash('info', message, details, timestamp, ev.id);
      }

      // Immediately poll again after receiving data
      ns.pollServer();
    } catch (error) {
      console.error('Polling error:', error);
      setTimeout(ns.pollServer, 5000); // Retry after 5 seconds in case of error
    }
  };*/
});

$(function() {
  "use strict";
  //kivi.AsyncMsg.pollServer();
  kivi.AsyncMsg.connect_ws();
});
