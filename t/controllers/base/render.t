use strict;
use Test::Exception;
use Test::More tests => 19;
use Test::Output;

use lib 't';
use Support::TestSetup;

use SL::Presenter;
use SL::Controller::Base;
use SL::Layout::Javascript;

no warnings 'uninitialized';

Support::TestSetup::login();

sub reset_test_env {
  $ENV{HTTP_USER_AGENT} = 'Perl Tests';

  $::request = Support::TestSetup->create_new_request(
    layout => SL::Layout::Javascript->new,
  );

  $::myconfig{menustyle} = 'javascript';

  delete @{ $::form }{qw(header footer)};
}

my $ctrl = SL::Controller::Base->new;

# Passing invalid parameters:
throws_ok { $ctrl->render(\'dummy', { unknown => 1 }) }    qr/unsupported option/i,                     'string ref, unknown parameter';
throws_ok { $ctrl->render(\'dummy', { type => "excel" }) } qr/unsupported type/i,                       'string ref, unsupported "type"';
throws_ok { $ctrl->render({}) }                            qr/unsupported.*template.*reference.*type/i, 'string ref, unsupported template argument reference type';
throws_ok { $ctrl->render('does/not/exist') }              qr/template.*file.*not.*found/i,             'non-existing template file name';

# No output:
stdout_is { $ctrl->render(\'Hallo', { output => 0 }) } '', 'no output';

# Type of return value:
is(ref($ctrl->render(\'Hallo', { output => 0 })), 'SL::Presenter::EscapedText', 'render returns SL::Presenter::EscapedText');

# Actual return value for string ref parameters (enforce stringification from SL::Presenter::EscapedText before comparison):
is("" . $ctrl->render(\'Hallo [% world %]', { output => 0 }, world => 'Welt'),               'Hallo Welt',        'render string ref, no output');
is("" . $ctrl->render(\'Hallo [% world %]', { output => 0, process => 0 }, world => 'Welt'), 'Hallo [% world %]', 'render string ref, no output, no processing');
is("" . $ctrl->render(\'Hallo [% world %]', { output => 0, type => 'js' }, world => 'Welt'), 'Hallo Welt',        'render string ref, no output, different type');

# Actual return value for template file name parameters (enforce stringification from SL::Presenter::EscapedText before comparison):
is("" . $ctrl->render('t/render', { output => 0 }, world => 'Welt'),                      "Hallo Welt\n",                                       'render template file, no args');
is("" . $ctrl->render('t/render', { output => 0, process => 0 }, world  => 'Welt'),   "[\% USE HTML \%]Hallo [\% HTML.escape(world) \%]\n", 'render template file, no processing');
is("" . $ctrl->render('t/render', { output => 0, type => 'js' }, thingy => 'jungle'), "Welcome to the jungle\n",                            'render template file, different type');

# No HTTP header in screen output:
reset_test_env();
stdout_unlike { $ctrl->render(\'Hallo [% world %]', { header => 0 }, world => 'Welt') } qr/content-type/i, 'no HTTP header with header=0';

reset_test_env();
stdout_unlike { $ctrl->render(\'Hallo [% world %]', { header => 0 }, world => 'Welt') } qr/<html>/i,       'no HTML header with header=0';

# With HTTP header in screen output:
reset_test_env();
stdout_like { $ctrl->render(\'Hallo [% world %]', world => 'Welt') } qr/content-type/i, 'HTTP header with header=1';

reset_test_env();
stdout_like { $ctrl->render(\'Hallo [% world %]', world => 'Welt') } qr/<html>/i,       'HTML header with header=1';

# Menu yes/no:
reset_test_env();
stdout_like { $ctrl->render(\'Hallo [% world %]', world => 'Welt') } qr/<div.*id="main_menu_div".*<ul.*id="main_menu_model"/is, 'HTML header & menu with header=1';

reset_test_env();
stdout_unlike { $ctrl->render(\'Hallo [% world %]', { header => 0 }, world => 'Welt') } qr/<div.*id="main_menu_div".*<ul.*id="main_menu_model"/is, 'HTML header & menu with header=0';

reset_test_env();
stdout_unlike { $ctrl->render(\'Hallo [% world %]', { layout => 0 }, world => 'Welt') } qr/<div.*id="main_menu_div".*<ul.*id="main_menu_model"/is, 'HTML header & menu with layout=0';

done_testing;

1;
