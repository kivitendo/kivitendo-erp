// Hot reload server for local development
//
// Description: This script implements a simple web socket server that watches
// relevant directories for changes and sends a reload signal to the connected
// browser clients to reload the page on a change. When the change occurs in the
// less files, it also recompiles the less files to css.
//
// It is intended for local development, do not use it on a production server.
//
// The script is written for bun. A standalone javascript runtime, see: https://bun.sh/
//
// Requirements:
// - bun (tested with version 1.2.9)
// - lessc (when working with less files)
//
// Usage:
// 1) enable hot_reload in the kivitendo.conf
//    (this injects the minimal javascript required on the client side)
// 2) run this server script alongside your regular web server using:
//
//      bun run hotreload-server.js
//
// 3) the browser client has to be refreshed once manually in order to load the
//    javascript and connect to the websocket server, after that the browser
//    should automatically reload the page when a change occurred (e.g. saving a file)
//
// Currently the port is hard coded in the javascript client. If you want to change
// the port, you have to change it in the client script and below. See js/hotreload.js
//

import { watch } from "fs";
import { $ } from "bun";

// only accept local connections
const hostname = "127.0.0.1";
const port = 7575;

const pathsToWatch = [
  '../bin',
  '../css',
  '../dispatcher.fcgi',
  '../dispatcher.pl',
  '../locale',
  '../SL',
  '../templates',
  '../config',
  '../dispatcher.fpl',
  '../js',
  '../t',
];

let connections = [];

// returns a function that wraps the given function and calls it
// only if the timer has expired
const rateLimit = (fn, delay) => {
  let timer = null;
  return (...args) => {
    if (timer === null) {
      fn(...args);
      timer = setTimeout(() => {
        timer = null;
      }, delay);
    }
  };
};

const sendMessage = (ws, message) => {
  try {
    ws.send(JSON.stringify(message));
  } catch (error) {
    console.error("Error sending error message to browser:", error);
  }
};

const reloadCallback = async (event, filename) => {
  connections.forEach(async ws => {
    console.info(`Detected ${event} in ${filename}`);
    if (filename === "design40/main.css") {
      // avoid re-detecting changes after compiling less
      console.info("Change in design40/main.css detected, ignoring to avoid recursive detection.");
      return;
    }
    if (filename.startsWith('design40/less/')) {
      // execute lessc compiler
      console.info("Compiling less files.");
      try {
        await $`lessc -x ../css/design40/less/style.less ../css/design40/style.css`.quiet();
      } catch (err) {
        const errorMessage = `Error compiling less files: Failed with code ${err.exitCode}`;
        console.error(errorMessage);
        // NOTE: it would be nice to send the entire message to the client and display it on
        // an error page but that would require some more work on the client
        sendMessage(ws, { type: "error", message: errorMessage });
        console.error(err.stdout.toString());
        console.error(err.stderr.toString());
        return;
      }
    }
    console.info("Sending reload to web socket client (browser).");
    sendMessage(ws, { type: "reload" });
    ws.close()
  });
}

pathsToWatch.forEach(path => {
  watch(
    path,
    { recursive: true, },
    rateLimit(reloadCallback, 1000),
  );
});

Bun.serve({
  hostname,
  port,
  fetch(req, server) {
    // upgrade the request to a WebSocket
    // (according to bun example code)
    if (server.upgrade(req)) {
      return; // do not return a Response
    }
    return new Response("Upgrade failed.", { status: 500 });
  },
  websocket: {
    open(ws) {
      console.info("Connection established.");
      connections.push(ws);
    },
    close(ws) {
      console.info("Connection closed.");
      connections = connections.filter(conn => conn !== ws);
    },
  },
});

console.info("Server started, refresh kivitendo in the browser to establish a connection.");
