namespace('kivi.AssemblyPlot', function(ns) {
  'use strict';

  ns.get_test_objects = () => {
    return [
      {id :  5, parentId : 4},
      {id :  6, parentId : 4},
      {id :  7, parentId : 4},
      {id :  8, parentId : 4},
      {id :  4, parentId : 3},
      {id :  9, parentId : 3},
      {id : 10, parentId : 3},
      {id :  2, parentId : 1},
      {id :  3, parentId : 1},
      {id : 11, parentId : 1},
      {id :  1, parentId : undefined}
    ];
  };

  ns.get_objects = () => {
    let objects;
    $.ajax({
      url: 'controller.pl',
      data: {action: 'AssemblyPlot/get_objects',
             id: $('#id').val(),
             recursively: $('#recursively').val()
            },
      method: 'POST',
      async:  false,
      dataType: 'json',
      success: function(data){
        objects = data;
      }
    });
    return objects;
  };

  ns.chart = (data) => {
    const width = 1800;

    // Compute the tree height; this approach will allow the height of the
    // SVG to scale according to the breadth (width) of the tree layout.
    const root = data; //d3.hierarchy(data);

    const dx = 50;
    const dy = width / (root.height +1);

    // Create a tree layout.
    const tree = d3.tree().nodeSize([dx, dy]);

    // Sort the tree and apply the layout.
    //root.sort((a, b) => d3.ascending(a.data.partnumber, b.data.partnumber));
    tree(root);

    // Compute the extent of the tree. Note that x and y are swapped here
    // because in the tree layout, x is the breadth, but when displayed, the
    // tree extends right rather than down.
    let x0 = Infinity;
    let x1 = -x0;
    root.each(d => {
      if (d.x > x1) x1 = d.x;
      if (d.x < x0) x0 = d.x;
    });

    const text_f = 0.65;

    // Compute the adjusted height of the tree.
    const height = x1 - x0 + dx * 2;

    const svg = d3.create("svg")
          .attr("width", width)
          .attr("height", height)
          .attr("viewBox", [-dy / 3, x0 - dx, width, height])
          .attr("style", "max-width: 100%; height: auto; font: 10px sans-serif;");

    const link = svg.append("g")
          .attr("fill", "none")
          .attr("stroke", "#555")
          .attr("stroke-opacity", 0.4)
          .attr("stroke-width", 1.5)
          .selectAll()
          .data(root.links())
          .join("path")
          .attr("d", d3.linkHorizontal()
                .x(d => d.y)
                .y(d => d.x));

    const node = svg.append("g")
          .attr("stroke-linejoin", "round")
          .attr("stroke-width", 3)
          .selectAll("a")
          .data(root.descendants())
          .join("a")
          .attr("xlink:href", d => d.data.link)
          .attr("target", "_blank")
          .attr("style", "text-decoration: none;")
          .attr("transform", d => `translate(${d.y},${d.x})`);

    node.append("rect")
      .attr("fill", d => d.children ? "#555" : "#999")
      .attr("width", d => (text_f * ((d.data.qty ? d.data.qty + "x " : "") +  d.data.description + "  " + d.data.partnumber) .length) + "em")
      .attr("height", "4em")
      .attr("x", 0)
      .attr("y", "-1em")
      .attr("opacity", 0.5)
    ;

    node.append("text")
      .attr("dy", "0.31em")
      .attr("x", 6)
      .text(d => (d.data.qty ? d.data.qty + "x " : "") +  d.data.description + "  " + d.data.partnumber)
      .attr("stroke", "white")
      .attr("paint-order", "stroke");

    node.append("text")
      .attr("dy", "2em")
      .attr("x", 6)
      .text(d => d.data.partnumber)
      .attr("stroke", "white")
      .attr("paint-order", "stroke");

    return svg.node();
  };

  $(() => {
    const objects = ns.get_objects();
    let root = d3.stratify()(objects);
    let svg = ns.chart(root);

    $('#svg').html(svg);
  });

});
