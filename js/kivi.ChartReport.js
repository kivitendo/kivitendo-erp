namespace('kivi.ChartReport', function(ns) {
  "use strict";

  ns.data = undefined;

  ns.background_colors = function() { return [
    'rgba(255, 0, 0, 0.2)',
    'rgba(63, 0, 0, 0.2)',
    'rgba(0, 127, 0, 0.2)',
    'rgba(0, 0, 191, 0.2)',
    'rgba(191, 0, 0, 0.2)',
    'rgba(0, 255, 0, 0.2)',
    'rgba(0, 63, 0, 0.2)',
    'rgba(0, 0, 127, 0.2)',
    'rgba(127, 0, 0, 0.2)',
    'rgba(0, 191, 0, 0.2)',
    'rgba(0, 0, 255, 0.2)',
    'rgba(0, 0, 63, 0.2)'
  ]};

  ns.border_colors = function() { return [
    'rgba(255, 0, 0, 1.0)',
    'rgba(63, 0, 0, 1.0)',
    'rgba(0, 127, 0, 1.0)',
    'rgba(0, 0, 191, 1.0)',
    'rgba(191, 0, 0, 1.0)',
    'rgba(0, 255, 0, 1.0)',
    'rgba(0, 63, 0, 1.0)',
    'rgba(0, 0, 127, 1.0)',
    'rgba(127, 0, 0, 1.0)',
    'rgba(0, 191, 0, 1.0)',
    'rgba(0, 0, 255, 1.0)',
    'rgba(0, 0, 63, 1.0)'
  ]};

  ns.chart = function() {
    $(ns.data.datasets).each(function(idx, elt) {
      $(elt).each(function(idx) {elt[idx] = kivi.parse_amount('' + elt[idx]);console.log(elt[idx]);});
    });

    const datasets = [];
    for (let i = 0; i < ns.data.data_labels.length; i++) {
      const set = [];
      $(ns.data.datasets).each(function(idx, elt) {set.push(elt[i]);});
      const colots = [];
      datasets.push({label: ns.data.data_labels[i],
                     data: set,
                     backgroundColor: ns.background_colors()[i % ns.background_colors().length],
                     borderColor: ns.border_colors()[i % ns.border_colors().length],
                     borderWidth: 1
                    });
    }

    const ctx = 'chart';
    const chart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: ns.data.labels,
        datasets: datasets,
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
    console.log("bb: labels: "); console.log(ns.data.labels);
    console.log("bb: datasets: "); console.log(ns.data.datasets);
    console.log("bb: data_labels: "); console.log(ns.data.data_labels);
  };

  $(function() {
    kivi.ChartReport.debug();
    kivi.ChartReport.chart();
  });
});
