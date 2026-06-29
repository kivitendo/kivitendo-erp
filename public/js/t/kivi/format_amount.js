QUnit.test("kivi.format_amount function German number style with thousand separator", function( assert ) {
  kivi.setup_formats({ numbers: '1.000,00' });

  assert.equal(kivi.format_amount('1e1', 2), '10,00', 'format 1e1');
  assert.equal(kivi.format_amount(1000, 2), '1.000,00', 'format 1000');
  assert.equal(kivi.format_amount(1000.1234, 2), '1.000,12', 'format 1000.1234');
  assert.equal(kivi.format_amount(1000000000.1234, 2), '1.000.000.000,12', 'format 1000000000.1234');
  assert.equal(kivi.format_amount(-1000000000.1234, 2), '-1.000.000.000,12', 'format -1000000000.1234');
});

QUnit.test("kivi.format_amount function German number style without thousand separator", function( assert ) {
  kivi.setup_formats({ numbers: '1000,00' });

  assert.equal(kivi.format_amount('1e1', 2), '10,00', 'format 1e1');
  assert.equal(kivi.format_amount(1000, 2), '1000,00', 'format 1000');
  assert.equal(kivi.format_amount(1000.1234, 2), '1000,12', 'format 1000.1234');
  assert.equal(kivi.format_amount(1000000000.1234, 2), '1000000000,12', 'format 1000000000.1234');
  assert.equal(kivi.format_amount(-1000000000.1234, 2), '-1000000000,12', 'format -1000000000.1234');
});

QUnit.test("kivi.format_amount function English number style with thousand separator", function( assert ) {
  kivi.setup_formats({ numbers: '1,000.00' });

  assert.equal(kivi.format_amount('1e1', 2), '10.00', 'format 1e1');
  assert.equal(kivi.format_amount(1000, 2), '1,000.00', 'format 1000');
  assert.equal(kivi.format_amount(1000.1234, 2), '1,000.12', 'format 1000.1234');
  assert.equal(kivi.format_amount(1000000000.1234, 2), '1,000,000,000.12', 'format 1000000000.1234');
  assert.equal(kivi.format_amount(-1000000000.1234, 2), '-1,000,000,000.12', 'format -1000000000.1234');
});

QUnit.test("kivi.format_amount function English number style without thousand separator", function( assert ) {
  kivi.setup_formats({ numbers: '1000.00' });

  assert.equal(kivi.format_amount('1e1', 2), '10.00', 'format 1e1');
  assert.equal(kivi.format_amount(1000, 2), '1000.00', 'format 1000');
  assert.equal(kivi.format_amount(1000.1234, 2), '1000.12', 'format 1000.1234');
  assert.equal(kivi.format_amount(1000000000.1234, 2), '1000000000.12', 'format 1000000000.1234');
  assert.equal(kivi.format_amount(-1000000000.1234, 2), '-1000000000.12', 'format -1000000000.1234');
});

QUnit.test("kivi.format_amount function Swiss number style with thousand separator", function( assert ) {
  kivi.setup_formats({ numbers: '1\'000.00' });

  assert.equal(kivi.format_amount('1e1', 2), '10.00', 'format 1e1');
  assert.equal(kivi.format_amount(1000, 2), '1\'000.00', 'format 1000');
  assert.equal(kivi.format_amount(1000.1234, 2), '1\'000.12', 'format 1000.1234');
  assert.equal(kivi.format_amount(1000000000.1234, 2), '1\'000\'000\'000.12', 'format 1000000000.1234');
  assert.equal(kivi.format_amount(-1000000000.1234, 2), '-1\'000\'000\'000.12', 'format -1000000000.1234');
});

QUnit.test("kivi.format_amount function negative places", function( assert ) {
  kivi.setup_formats({ numbers: '1000.00' });

  assert.equal(kivi.format_amount(1.00045, -2), '1.00045', 'negative places');
  assert.equal(kivi.format_amount(1.00045, -5), '1.00045', 'negative places 2');
  assert.equal(kivi.format_amount(1, -2), '1.00', 'negative places 3');
});

QUnit.test("kivi.format_amount function bugs and edge cases", function( assert ) {
  kivi.setup_formats({ numbers: '1.000,00' });

  assert.equal(kivi.format_amount(0.00005), '0,00005', 'messing with small numbers and no precision');
  assert.equal(kivi.format_amount(undefined), '0', 'undefined');
  assert.equal(kivi.format_amount(''), '0', 'empty string');
  assert.equal(kivi.format_amount(undefined, 2), '0,00', 'undefined with precision');
  assert.equal(kivi.format_amount('', 2), '0,00', 'empty string with prcesion');

  assert.equal(kivi.format_amount(0.545, 0), '1', 'rounding up with precision 0');
  assert.equal(kivi.format_amount(-0.545, 0), '-1', 'neg rounding up with precision 0');

  assert.equal(kivi.format_amount(1.00), '1', 'autotrim to 0 places');

  assert.equal(kivi.format_amount(10), '10', 'autotrim does not harm integers');
  assert.equal(kivi.format_amount(10, 2), '10,00' , 'autotrim does not harm integers 2');
  assert.equal(kivi.format_amount(10, -2), '10,00' , 'autotrim does not harm integers 3');
  assert.equal(kivi.format_amount(10, 0), '10', 'autotrim does not harm integers 4');

  assert.equal(kivi.format_amount(0, 0), '0' , 'trivial zero');
});
