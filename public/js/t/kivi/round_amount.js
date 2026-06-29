QUnit.test("kivi.round_amount function, 0..2 places", function( assert ) {
  assert.equal(kivi.round_amount(1.05, 2), '1.05', '1.05 @ 2');
  assert.equal(kivi.round_amount(1.05, 1), '1.1',  '1.05 @ 1');
  assert.equal(kivi.round_amount(1.05, 0), '1',    '1.05 @ 0');

  assert.equal(kivi.round_amount(1.045, 2), '1.05', '1.045 @ 2');
  assert.equal(kivi.round_amount(1.045, 1), '1',    '1.045 @ 1');
  assert.equal(kivi.round_amount(1.045, 0), '1',    '1.045 @ 0');

  assert.equal(kivi.round_amount(33.675, 2), '33.68', '33.675 @ 2');
  assert.equal(kivi.round_amount(33.675, 1), '33.7',  '33.675 @ 1');
  assert.equal(kivi.round_amount(33.675, 0), '34',    '33.675 @ 0');

  assert.equal(kivi.round_amount(64.475, 2), '64.48', '64.475 @ 2');
  assert.equal(kivi.round_amount(64.475, 1), '64.5',  '64.475 @ 1');
  assert.equal(kivi.round_amount(64.475, 0), '64',    '64.475 @ 0');

  assert.equal(kivi.round_amount(44.9 * 0.75, 2), '33.68', '44.9 * 0.75 @ 2');
  assert.equal(kivi.round_amount(44.9 * 0.75, 1), '33.7',  '44.9 * 0.75 @ 1');
  assert.equal(kivi.round_amount(44.9 * 0.75, 0), '34',    '44.9 * 0.75 @ 0');

  assert.equal(kivi.round_amount(143.20, 2), '143.2', '143.20 @ 2');
  assert.equal(kivi.round_amount(143.20, 1), '143.2', '143.20 @ 1');
  assert.equal(kivi.round_amount(143.20, 0), '143',   '143.20 @ 0');

  assert.equal(kivi.round_amount(149.175, 2), '149.18', '149.175 @ 2');
  assert.equal(kivi.round_amount(149.175, 1), '149.2',  '149.175 @ 1');
  assert.equal(kivi.round_amount(149.175, 0), '149',    '149.175 @ 0');

  assert.equal(kivi.round_amount(198.90 * 0.75, 2), '149.18', '198.90 * 0.75 @ 2');
  assert.equal(kivi.round_amount(198.90 * 0.75, 1), '149.2',  '198.90 * 0.75 @ 1');
  assert.equal(kivi.round_amount(198.90 * 0.75, 0), '149',    '198.90 * 0.75 @ 0');
});

QUnit.test("kivi.round_amount function, 0..5 places", function( assert ) {
  assert.equal(kivi.round_amount(64.475499, 5), '64.4755', '64.475499 @ 5');
  assert.equal(kivi.round_amount(64.475499, 4), '64.4755', '64.475499 @ 4');
  assert.equal(kivi.round_amount(64.475499, 3), '64.475',  '64.475499 @ 3');
  assert.equal(kivi.round_amount(64.475499, 2), '64.48',   '64.475499 @ 2');
  assert.equal(kivi.round_amount(64.475499, 1), '64.5',    '64.475499 @ 1');
  assert.equal(kivi.round_amount(64.475499, 0), '64',      '64.475499 @ 0');

  assert.equal(kivi.round_amount(64.475999, 5), '64.476', '64.475999 @ 5');
  assert.equal(kivi.round_amount(64.475999, 4), '64.476', '64.475999 @ 4');
  assert.equal(kivi.round_amount(64.475999, 3), '64.476', '64.475999 @ 3');
  assert.equal(kivi.round_amount(64.475999, 2), '64.48',  '64.475999 @ 2');
  assert.equal(kivi.round_amount(64.475999, 1), '64.5',   '64.475999 @ 1');
  assert.equal(kivi.round_amount(64.475999, 0), '64',     '64.475999 @ 0');
});

QUnit.test("kivi.round_amount function, negative values", function( assert ) {
  // Negative values
  assert.equal(kivi.round_amount(-1.05, 2), '-1.05', '-1.05 @ 2');
  assert.equal(kivi.round_amount(-1.05, 1), '-1.1',  '-1.05 @ 1');
  assert.equal(kivi.round_amount(-1.05, 0), '-1',    '-1.05 @ 0');

  assert.equal(kivi.round_amount(-1.045, 2), '-1.05', '-1.045 @ 2');
  assert.equal(kivi.round_amount(-1.045, 1), '-1',    '-1.045 @ 1');
  assert.equal(kivi.round_amount(-1.045, 0), '-1',    '-1.045 @ 0');

  assert.equal(kivi.round_amount(-33.675, 2), '-33.68', '33.675 @ 2');
  assert.equal(kivi.round_amount(-33.675, 1), '-33.7',  '33.675 @ 1');
  assert.equal(kivi.round_amount(-33.675, 0), '-34',    '33.675 @ 0');

  assert.equal(kivi.round_amount(-44.9 * 0.75, 2), '-33.68', '-44.9 * 0.75 @ 2');
  assert.equal(kivi.round_amount(-44.9 * 0.75, 1), '-33.7',  '-44.9 * 0.75 @ 1');
  assert.equal(kivi.round_amount(-44.9 * 0.75, 0), '-34',    '-44.9 * 0.75 @ 0');

  assert.equal(kivi.round_amount(-149.175, 2), '-149.18', '-149.175 @ 2');
  assert.equal(kivi.round_amount(-149.175, 1), '-149.2',  '-149.175 @ 1');
  assert.equal(kivi.round_amount(-149.175, 0), '-149',    '-149.175 @ 0');

  assert.equal(kivi.round_amount(-198.90 * 0.75, 2), '-149.18', '-198.90 * 0.75 @ 2');
  assert.equal(kivi.round_amount(-198.90 * 0.75, 1), '-149.2',  '-198.90 * 0.75 @ 1');
  assert.equal(kivi.round_amount(-198.90 * 0.75, 0), '-149',    '-198.90 * 0.75 @ 0');
});

QUnit.test("kivi.round_amount function, programmatic tests of all 0..1000", function( assert ) {
  $([ -1, 1 ]).each(function(dummy, sign) {
    for (var idx = 0; idx < 1000; idx++) {
      var num = (9900000 * sign) + idx;
      var str = "" + num;
      str     = str.substr(0, str.length - 2) + "." + str.substr(str.length - 2, 2);
      str     = str.replace(/0+$/, '').replace(/\.$/, '');

      num /= 100;
      num /= 5;
      num /= 3;
      num *= 5;
      num *= 3;

      assert.equal("" + kivi.round_amount(num, 2), str);
    }
  });
});

QUnit.test("kivi.round_amount function, up to 10 digits of Pi", function( assert ) {
  // round to any digit we like
  assert.equal(kivi.round_amount(Math.PI, 0),  '3',             "0 digits of π");
  assert.equal(kivi.round_amount(Math.PI, 1),  '3.1',           "1 digit of π");
  assert.equal(kivi.round_amount(Math.PI, 2),  '3.14',          "2 digits of π");
  assert.equal(kivi.round_amount(Math.PI, 3),  '3.142',         "3 digits of π");
  assert.equal(kivi.round_amount(Math.PI, 4),  '3.1416',        "4 digits of π");
  assert.equal(kivi.round_amount(Math.PI, 5),  '3.14159',       "5 digits of π");
  assert.equal(kivi.round_amount(Math.PI, 6),  '3.141593',      "6 digits of π");
  assert.equal(kivi.round_amount(Math.PI, 7),  '3.1415927',     "7 digits of π");
  assert.equal(kivi.round_amount(Math.PI, 8),  '3.14159265',    "8 digits of π");
  assert.equal(kivi.round_amount(Math.PI, 9),  '3.141592654',   "9 digits of π");
  assert.equal(kivi.round_amount(Math.PI, 10), '3.1415926536', "10 digits of π");
});

QUnit.test("kivi.round_amount function, other weird cases", function( assert ) {
  // A LOT of places:
  assert.equal(kivi.round_amount(1.2, 200), '1.2', '1.2 @ 200');
});
