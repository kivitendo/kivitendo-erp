use Test::More;

use_ok 'SL::HTML::Util';

sub test {
  is(SL::HTML::Util::strip($_[0]), $_[1], "$_[2] (direct invocation)");
  is(SL::HTML::Util->strip($_[0]), $_[1], "$_[2] (class invocation)");
}

test undef, '', 'undef';
test 0, '0', '0';
test '0 but true', '0 but true', 'zero but true';
test '<h1>title</h1>', 'title', 'standard case';
test '<h1>title</h2>', 'title', 'imbalanced html';
test 'walter &amp; walter', 'walter & walter', 'known entities';
test 'Walter&Walter; Chicago', 'Walter&Walter; Chicago', 'unknown entities';
test '<h1>title</h1', 'title', 'invalid html 1';

# This happens when someone copies a block from MS Word. The HTML that is
# generated contains style information in comments. These styles can contain
# sgml. HTML::Parser does not handle these properly.
test '<!-- style: <>  -->title', 'title', 'nested stuff in html comments';

done_testing;
