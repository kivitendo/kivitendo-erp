use strict;
use Test::Exception;
use Test::More tests => 11;

use lib 't';
use Support::TestSetup;

use SL::Presenter;

Support::TestSetup::login();

my $pr = SL::Presenter->get;

# Passing invalid parameters:
throws_ok { $pr->render(\'dummy', { unknown => 1 }) }    qr/unsupported option/i,                     'string ref, unknown parameter';
throws_ok { $pr->render(\'dummy', { type => "excel" }) } qr/unsupported type/i,                       'string ref, unsupported "type"';
throws_ok { $pr->render({}) }                            qr/unsupported.*template.*reference.*type/i, 'string ref, unsupported template argument reference type';
throws_ok { $pr->render('does/not/exist') }              qr/template.*file.*not.*found/i,             'non-existing template file name';

# Type of return value:
is(ref($pr->render(\'Hallo')), 'SL::Presenter::EscapedText', 'render returns SL::Presenter::EscapedText');

# Actual return value for string ref parameters (enforce stringification from SL::Presenter::EscapedText before comparison):
is("" . $pr->render(\'Hallo [% world %]', world => 'Welt'),                   'Hallo Welt',        'render string ref, no args');
is("" . $pr->render(\'Hallo [% world %]', { process => 0 }, world => 'Welt'), 'Hallo [% world %]', 'render string ref, no processing');
is("" . $pr->render(\'Hallo [% world %]', { type => 'js' }, world => 'Welt'), 'Hallo Welt',        'render string ref, different type');

# Actual return value for template file name parameters (enforce stringification from SL::Presenter::EscapedText before comparison):
is("" . $pr->render('t/render', world => 'Welt'),                      "Hallo Welt\n",                                       'render template file, no args');
is("" . $pr->render('t/render', { process => 0 }, world  => 'Welt'),   "[\% USE HTML \%]Hallo [\% HTML.escape(world) \%]\n", 'render template file, no processing');
is("" . $pr->render('t/render', { type => 'js' }, thingy => 'jungle'), "Welcome to the jungle\n",                            'render template file, different type');

done_testing;

1;
