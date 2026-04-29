use Test::More tests => 15;

use strict;

use lib 't';

use Support::TestSetup;
use List::MoreUtils qw(none any);

use SL::DB::Contact;
use SL::DB::CustomVariableConfig;
use SL::DB::Default;

use SL::Controller::CsvImport;
use_ok 'SL::Controller::CsvImport::Contact';

Support::TestSetup::login();

#####
sub do_import {
  my ($file, $settings) = @_;

  my $controller = SL::Controller::CsvImport->new(
    type => 'contacts',
  );
  $controller->load_default_profile;
  $controller->profile->set(
    charset            => 'utf-8',
    sep_char           => ';',
    default_country_id => 1,
    %$settings
  );

  my $worker = SL::Controller::CsvImport::Contact->new(
    controller => $controller,
    file       => $file,
  );
  $worker->run(test => 0);

  return if $worker->controller->errors;

  # don't try and save objects that have errors
  $worker->save_objects unless scalar @{$worker->controller->data->[0]->{errors}};

  return $worker->controller->data;
}

sub _obj_of {
  return $_[0]->{object_to_save} || $_[0]->{object};
}

sub clear_up {
  SL::DB::Manager::Contact->delete_all(all => 1);
  SL::DB::Manager::CustomVariableConfig->delete_all(all => 1);

  # Reset request to clear caches. Here especially for cvar-configs.
  $::request = Support::TestSetup->create_new_request;
}

#####

# set numberformat and locale (so we can match errors)
my $old_numberformat      = $::myconfig{numberformat};
$::myconfig{numberformat} = '1.000,00';
my $old_locale            = $::locale;
$::locale                 = Locale->new('en');

clear_up;

#####
# import and update entries

my $file = \<<'EOL';
cp_givenname;cp_name;cp_email;cp_street;cp_city;cp_country;cp_abteilung
Ada;Lovelace;ada@no.domain;5th Avenue;Brooklyn;United Kingdom;R&D
EOL

my $entries = do_import($file, {update_policy => 'update_existing'});

is _obj_of($entries->[0])->cp_abteilung,     'R&D',              'import entry - cp_abteilung1';
is _obj_of($entries->[0])->cp_name,          'Lovelace',         'import entry - cp_name';
is _obj_of($entries->[0])->cp_givenname,     'Ada',              'import entry - cp_givenname';
is _obj_of($entries->[0])->cp_email,         'ada@no.domain',    'import entry - cp_email';
is _obj_of($entries->[0])->cp_street,        '5th Avenue',       'import entry - cp_street';
is _obj_of($entries->[0])->cp_city,          'Brooklyn',         'import entry - cp_city';
is _obj_of($entries->[0])->cp_country->iso2, 'GB',               'import entry - cp_country';

$entries = undef;

clear_up;

$file = \<<'EOL';
cp_givenname;cp_name;cp_email;cp_street;cp_city;cp_country;cp_abteilung
George;Byron;george@no.domain;5th Avenue;Brooklyn;;R&D
EOL

$entries = do_import($file, {update_policy => 'update_existing'});

is _obj_of($entries->[0])->cp_abteilung,     'R&D',              'import entry - cp_abteilung1';
is _obj_of($entries->[0])->cp_name,          'Byron',            'import entry - cp_name';
is _obj_of($entries->[0])->cp_givenname,     'George',           'import entry - cp_givenname';
is _obj_of($entries->[0])->cp_email,         'george@no.domain', 'import entry - cp_email';
is _obj_of($entries->[0])->cp_street,        '5th Avenue',       'import entry - cp_street';
is _obj_of($entries->[0])->cp_city,          'Brooklyn',         'import entry - cp_city';
is _obj_of($entries->[0])->cp_country,       undef,              'import entry - cp_country';

$entries = undef;

clear_up;


$::myconfig{numberformat} = $old_numberformat;
$::locale                 = $old_locale;

1;

#####
# vim: ft=perl
# set emacs to perl mode
# Local Variables:
# mode: perl
# End:
