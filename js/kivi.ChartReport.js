namespace('kivi.ChartReport', function(ns) {
  "use strict";

  ns.data = undefined;

  ns.chart = function() {
    $(ns.data.data_y).each(function(idx) {ns.data.data_y[idx] = kivi.parse_amount('' + ns.data.data_y[idx]);});
    console.log("bb: data_y (parsed): "); console.log(ns.data.data_y);

    const ctx = 'chart';
    const chart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: ns.data.data_x,
        datasets: [{
            label: ns.data.label_y,
          data: ns.data.data_y,
            backgroundColor: [
                'rgba(255, 99, 132, 0.2)',
                'rgba(54, 162, 235, 0.2)',
                'rgba(255, 206, 86, 0.2)',
                'rgba(75, 192, 192, 0.2)',
                'rgba(153, 102, 255, 0.2)',
                'rgba(255, 159, 64, 0.2)'
            ],
            borderColor: [
                'rgba(255, 99, 132, 1)',
                'rgba(54, 162, 235, 1)',
                'rgba(255, 206, 86, 1)',
                'rgba(75, 192, 192, 1)',
                'rgba(153, 102, 255, 1)',
                'rgba(255, 159, 64, 1)'
            ],
            borderWidth: 1
        }]
      },
      options: {
        scales: {
          y: {
            beginAtZero: true
          }
        }
      }
    });
  };

  ns.debug = function() {
    console.log("bb: data_x: "); console.log(ns.data.data_x);
    console.log("bb: data_y: "); console.log(ns.data.data_y);
    console.log("bb: label_x: "); console.log(ns.data.label_x);
    console.log("bb: label_y: "); console.log(ns.data.label_y);
  };

  $(function() {
    kivi.ChartReport.debug();
    kivi.ChartReport.chart();
  });
});
