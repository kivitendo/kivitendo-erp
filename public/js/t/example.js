// See http://api.qunitjs.com/ for documentation of available methods
// (especially the »asserts«).

// Run these tests in your browser by opening the URL
// …/controller.pl?action=JSTests/run

QUnit.test("example tests", function( assert ) {
  // Simple true/false tests:
  assert.ok(1 == "1", "Integer 1 equals string 1");

  // Comparing objects:
  var actual   = { chunky: "bacon" };
  var expected = { chunky: "bacon" };
  assert.deepEqual(actual, expected, "Objects can have equal value");

  // Test if an exception is thrown:
  assert.throws(function() { throw "Boom!"; });

  // If you want to see how something fails uncomment this:
  // assert.deepEqual({ we: "are not" }, { in: "Kansas anymore" });
});
