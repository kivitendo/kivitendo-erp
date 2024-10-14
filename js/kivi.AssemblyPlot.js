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

  // https://observablehq.com/@d3/collapsible-tree
  ns.collapsableChart = (data) => {

    // Specify the charts’ dimensions. The height is variable, depending on the layout.
    const marginTop = 10;
    const marginRight = 10;
    const marginBottom = 10;
    const marginLeft = 40;

    // Rows are separated by dx pixels, columns by dy pixels. These names can be counter-intuitive
    // (dx is a height, and dy a width). This because the tree must be viewed with the root at the
    // “bottom”, in the data domain. The width of a column is based on the tree’s height.
    //const root = d3.hierarchy(data);
    const root = data;
    const dx = 50;
    const text_f = 0.65;

    function generate_text(data) {
      const text = (data.qty ? data.qty + "x " : "") +  data.description + "  " + data.partnumber;
      return text;
    }

    let maxTextLength = 0;
    root.eachBefore(d => {
      const t = d.data.descr_text   = generate_text(d.data);
      const l = d.data.descr_length = text_f * t.length;
      if (maxTextLength < l) maxTextLength = l;
    });

    const dy = 10*maxTextLength + 30;
    const width = dy * (1 + root.height) + marginLeft + marginRight;

    // Define the tree layout and the shape for links.
    const tree = d3.tree().nodeSize([dx, dy]);
    const diagonal = d3.linkHorizontal().x(d => d.y).y(d => d.x);

    // Create the SVG container, a layer for the links and a layer for the nodes.
    const svg = d3.create("svg")
          .attr("width", width)
          .attr("height", dx)
          .attr("viewBox", [-marginLeft, -marginTop, width, dx])
          .attr("style", "max-width: 100%; height: auto; font: 10px sans-serif; user-select: none;");

    const gLink = svg.append("g")
          .attr("fill", "none")
          .attr("stroke", "#555")
          .attr("stroke-opacity", 0.4)
          .attr("stroke-width", 1.5);

    const gNode = svg.append("g")
          .attr("cursor", "pointer")
          .attr("pointer-events", "all");

    function update(event, source) {
      const duration = event?.altKey ? 2500 : 250; // hold the alt key to slow down the transition
      const nodes = root.descendants().reverse();
      const links = root.links();

      // Compute the new tree layout.
      tree(root);

      let left = root;
      let right = root;
      root.eachBefore(node => {
        if (node.x < left.x) left = node;
        if (node.x > right.x) right = node;
      });

      const height = right.x - left.x + marginTop + marginBottom;
      const transition = svg.transition()
            .duration(duration)
            .attr("height", height)
            .attr("viewBox", [-marginLeft, left.x - marginTop, width, height])
            .tween("resize", window.ResizeObserver ? null : () => () => svg.dispatch("toggle"));

      // Update the nodes…
      const node = gNode.selectAll("g")
            .data(nodes, d => d.id);

      // Enter any new nodes at the parent's previous position.
      const nodeEnter = node.enter().append("g")
            .attr("transform", d => `translate(${source.y0},${source.x0})`)
            .attr("fill-opacity", 0)
            .attr("stroke-opacity", 0)
            .on("click", (event, d) => {
              d.children = d.children ? null : d._children;
              update(event, d);
            });

      nodeEnter.append("circle")
        .attr("r", 2.5)
        .attr("fill", d => d._children ? "#555" : "#999")
        .attr("stroke-width", 10);

      nodeEnter.append("rect")
        .attr("fill", d => d.children ? "#555" : "#999")
        .attr("width", d => maxTextLength + "em")
        .attr("height", "4em")
        .attr("x", 0)
        .attr("y", "-1em")
        .attr("opacity", 0.5)
      ;

      nodeEnter.append("text")
        .attr("dy", "0.31em")
        .attr("x", d => 6)
        .attr("text-anchor", d => "start")
        .text(d => d.data.descr_text)
        .attr("stroke-linejoin", "round")
        .attr("stroke-width", 3)
        .attr("stroke", "white")
        .attr("paint-order", "stroke");

      // Transition nodes to their new position.
      const nodeUpdate = node.merge(nodeEnter).transition(transition)
            .attr("transform", d => `translate(${d.y},${d.x})`)
            .attr("fill-opacity", 1)
            .attr("stroke-opacity", 1);

      // Transition exiting nodes to the parent's new position.
      const nodeExit = node.exit().transition(transition).remove()
            .attr("transform", d => `translate(${source.y},${source.x})`)
            .attr("fill-opacity", 0)
            .attr("stroke-opacity", 0);

      // Update the links…
      const link = gLink.selectAll("path")
            .data(links, d => d.target.id);

      // Enter any new links at the parent's previous position.
      const linkEnter = link.enter().append("path")
            .attr("d", d => {
              const o = {x: source.x0, y: source.y0};
              return diagonal({source: o, target: o});
            });

      // Transition links to their new position.
      link.merge(linkEnter).transition(transition)
        .attr("d", d => {
          const dy = 10*maxTextLength; // + "em";
          const so = {x: d.source.x, y: d.source.y + dy};
          const to = {x: d.target.x, y: d.target.y};
          return diagonal(
            {source: so, target: to});
        });

      // Transition exiting nodes to the parent's new position.
      link.exit().transition(transition).remove()
        .attr("d", d => {
          const o = {x: source.x, y: source.y};
          return diagonal({source: o, target: o});
        });

      // Stash the old positions for transition.
      root.eachBefore(d => {
        d.x0 = d.x;
        d.y0 = d.y;
      });
    }

    // Do the first update to the initial configuration of the tree — where a number of nodes
    // are open (arbitrarily selected as the root, plus nodes with 7 letters).
    root.x0 = dy / 2;
    root.y0 = 0;
    root.descendants().forEach((d, i) => {
      d.id = i;
      d._children = d.children;
      //if (d.depth && d.data.name.length !== 7) d.children = null;
    });

    update(null, root);

    return svg.node();
  };

  $(() => {
    const objects = ns.get_objects();
    const root = d3.stratify()(objects);
    let svg;
    if ($('#alternative').val() == 1) {
      svg = ns.collapsableChart(root);
    } else {
      svg = ns.chart(root);
    }

    $('#svg').html(svg);
  });

});
