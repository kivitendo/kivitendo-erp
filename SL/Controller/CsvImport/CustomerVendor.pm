package SL::Controller::CsvImport::CustomerVendor;

use strict;

use SL::Helper::Csv;
use SL::DB::Business;
use SL::DB::CustomVariable;
use SL::DB::CustomVariableConfig;
use SL::DB::PaymentTerm;

use parent qw(SL::Controller::CsvImport::Base);

use Rose::Object::MakeMethods::Generic
(
 'scalar --get_set_init' => [ qw(table languages_by businesses_by) ],
);

sub init_table {
  my ($self) = @_;
  $self->table($self->controller->profile->get('table') eq 'customer' ? 'customer' : 'vendor');
}

sub init_class {
  my ($self) = @_;
  $self->class('SL::DB::' . ucfirst($self->table));
}

sub init_all_cvar_configs {
  my ($self) = @_;

  return SL::DB::Manager::CustomVariableConfig->get_all(where => [ module => 'CT' ]);
}

sub init_businesses_by {
  my ($self) = @_;

  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ SL::DB::Manager::Business->get_all } } ) } qw(id description) };
}

sub init_languages_by {
  my ($self) = @_;

  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ $self->all_languages } } ) } qw(id description article_code) };
}

sub check_objects {
  my ($self) = @_;

  my $numbercolumn  = $self->controller->profile->get('table') . "number";
  my %vcs_by_number = map { ( $_->$numbercolumn => 1 ) } @{ $self->existing_objects };

  foreach my $entry (@{ $self->controller->data }) {
    my $object = $entry->{object};

    next unless $self->check_name($entry);
    next unless $self->check_language($entry);
    next unless $self->check_business($entry);
    next unless $self->check_payment($entry);
    $self->handle_cvars($entry);

    if ($vcs_by_number{ $object->$numbercolumn }) {
      $entry->{object}->$numbercolumn('####');
    } else {
      $vcs_by_number{ $object->$numbercolumn } = $object;
    }
  }

  $self->add_columns(map { "${_}_id" } grep { exists $self->controller->data->[0]->{raw_data}->{$_} } qw(language business payment));
  $self->add_cvar_raw_data_columns;
}

sub check_duplicates {
  my ($self, %params) = @_;

  my $normalizer = sub { my $name = $_[0]; $name =~ s/[\s,\.\-]//g; return $name; };

  my %by_name;
  if ('check_db' eq $self->controller->profile->get('duplicates')) {
    %by_name = map { ( $normalizer->($_->name) => 'db' ) } @{ $self->existing_objects };
  }

  foreach my $entry (@{ $self->controller->data }) {
    next if @{ $entry->{errors} };

    my $name = $normalizer->($entry->{object}->name);
    if (!$by_name{$name}) {
      $by_name{$name} = 'csv';

    } else {
      push @{ $entry->{errors} }, $by_name{$name} eq 'db' ? $::locale->text('Duplicate in database') : $::locale->text('Duplicate in CSV file');
    }
  }
}

sub check_name {
  my ($self, $entry) = @_;

  my $name =  $entry->{object}->name;
  $name    =~ s/^\s+//;
  $name    =~ s/\s+$//;

  return 1 if $name;

  push @{ $entry->{errors} }, $::locale->text('Error: Name missing');
  return 0;
}

sub check_language {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # Check whether or not language ID is valid.
  if ($object->language_id && !$self->languages_by->{id}->{ $object->language_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid language');
    return 0;
  }

  # Map name to ID if given.
  if (!$object->language_id && $entry->{raw_data}->{language}) {
    my $language = $self->languages_by->{description}->{  $entry->{raw_data}->{language} }
                || $self->languages_by->{article_code}->{ $entry->{raw_data}->{language} };

    if (!$language) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid language');
      return 0;
    }

    $object->language_id($language->id);
  }

  return 1;
}

sub check_business {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # Check whether or not business ID is valid.
  if ($object->business_id && !$self->businesss_by->{id}->{ $object->business_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid business');
    return 0;
  }

  # Map name to ID if given.
  if (!$object->business_id && $entry->{raw_data}->{business}) {
    my $business = $self->businesses_by->{description}->{ $entry->{raw_data}->{business} };

    if (!$business) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid business');
      return 0;
    }

    $object->business_id($business->id);
  }

  return 1;
}

sub save_objects {
  my ($self, %params) = @_;

  my $numbercolumn   = $self->table . 'number';
  my $with_number    = [ grep { $_->{object}->$numbercolumn ne '####' } @{ $self->controller->data } ];
  my $without_number = [ grep { $_->{object}->$numbercolumn eq '####' } @{ $self->controller->data } ];

  map { $_->{object}->$numbercolumn('') } @{ $without_number };

  $self->SUPER::save_objects(data => $with_number);
  $self->SUPER::save_objects(data => $without_number);
}

sub field_lengths {
  return ( name           => 75,
           department_1   => 75,
           department_2   => 75,
           street         => 75,
           zipcode        => 10,
           city           => 75,
           country        => 75,
           contact        => 75,
           phone          => 30,
           fax            => 30,
           account_number => 15,
           bank_code      => 10,
           language       => 5,
           username       => 50,
           ustid          => 14,
           iban           => 100,
           bic            => 100,
         );
}

sub init_profile {
  my ($self) = @_;

  my $profile = $self->SUPER::init_profile;
  delete @{$profile}{qw(language business salesman payment)};

  return $profile;
}

# TODO:
# salesman_id -- Kunden mit Typ 'Verkäufer', falls $::vertreter an ist, ansonsten Employees

1;
