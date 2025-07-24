
$(document).ready(() => {

  const hotReloadServerPort = parseInt(kivi.hot_reload_server_port) || 7575;
  const hotReloadWebSocket = new WebSocket(`ws://localhost:${hotReloadServerPort}`);

  hotReloadWebSocket.onmessage = (event) => {
    let data;
    try {
      data = JSON.parse(event.data);
    } catch (error) {
      console.error('Error parsing message:', error);
    }
    if (data.type === 'reload') {
      window.location.reload();
    } else if (data.type === 'error') {
      alert(`${data.message}\nCheck the hot reload server output for more information.`);
    }
  };

  hotReloadWebSocket.onopen = () => {
    console.log('Connected to WebSocket server');
  };

  hotReloadWebSocket.onerror = (error) => {
    console.log('Error occurred:', error);
  };

  hotReloadWebSocket.onclose = () => {
    console.log('Disconnected from WebSocket server');
  };
});
