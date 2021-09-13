package SL::Controller::CsvImport::Helper::Consistency;

use strict;

use Data::Dumper;
use SL::DB::Default;
use SL::DB::Currency;
use SL::DB::TaxZone;
use SL::DB::Project;
use SL::DB::Department;

use SL::Helper::Csv::Error;

use parent qw(Exporter);
our @EXPORT = qw(check_currency check_taxzone check_project check_department check_customer_vendor handle_salesman handle_employee);

#
# public functions
#

sub check_currency {
  my ($self, $entry, %params) = @_;

  my $object = $entry->{object};

  # Check whether or not currency ID is valid.
  if ($object->currency_id && ! _currencies_by($self)->{id}->{ $object->currency_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid currency');
    return 0;
  }

  # Map name to ID if given.
  if (!$object->currency_id && $entry->{raw_data}->{currency}) {
    my $currency = _currencies_by($self)->{name}->{  $entry->{raw_data}->{currency} };
    if (!$currency) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid currency');
      return 0;
    }

    $object->currency_id($currency->id);

    # register currency_id for method copying later
    $self->clone_methods->{currency_id} = 1;
  }

  # Set default currency if none was given and take_default is true.
  $object->currency_id(_default_currency_id($self)) if !$object->currency_id and $params{take_default};

  $entry->{raw_data}->{currency_id} = $object->currency_id;

  return 1;
}

sub check_taxzone {
  my ($self, $entry, %params) = @_;

  my $object = $entry->{object};

  # Check whether the CSV contains the parameters taxzone_id or taxzone, and
  # check them for validity.
  # If one of them was given, but is invalid, return an error

  # If neither was given:
  # a) if param take_default was set, use the taxzone_id from the profile
  #    (customer/vendor import)
  # b) if param take_default was not set, do nothing, return without error, and
  #    taxzone_id may be set later by other means (order import uses cv settings)


  # if $object->taxzone_id is defined (from CSV line), check if it is valid
  if ($object->taxzone_id && ! _taxzones_by($self)->{id}->{ $object->taxzone_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid tax zone');
    return 0;
  }

  # if there was no taxzone_id in CSV, but a taxzone entry, check if it is a
  # valid taxzone and set the id
  if (!$object->taxzone_id && $entry->{raw_data}->{taxzone}) {
    my $taxzone = _taxzones_by($self)->{description}->{ $entry->{raw_data}->{taxzone} };
    if (!$taxzone) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid tax zone');
      return 0;
    }

    $object->taxzone_id($taxzone->id);
  }

  # The take_default option should only be used for the customer/vendor case,
  # as the default for imported orders is the taxzone according to the customer
  # or vendor
  # if neither taxzone_id nor taxzone were defined, use the default taxzone as
  # defined from the import settings (a default/fallback taxzone that is to be
  # used will always be selected)

  if (!$object->taxzone_id && $params{take_default}) {
    # my $default_id = $self->settings->{'default_taxzone'};
    my $default_id = $self->controller->profile->get('default_taxzone');
    $default_id ||= _default_taxzone_id($self);
    $object->taxzone_id($default_id);
    # check if default taxzone_id is valid just to be sure
    if (! _taxzones_by($self)->{id}->{ $object->taxzone_id }) {
      push @{ $entry->{errors} }, $::locale->text('Error with default taxzone');
      return 0;
    }
  };

  # for the order import at this stage $object->taxzone_id may still not be
  # defined, in this case the customer/vendor taxzone will be used later
  if ( defined $object->taxzone_id ) {
    $entry->{info_data}->{taxzone} = _taxzones_by($self)->{id}->{ $object->taxzone_id }->description;
  };

  return 1;
}

sub check_project {
  my ($self, $entry, %params) = @_;

  my $id_column          = ($params{global} ? 'global' : '') . 'project_id';
  my $number_column      = ($params{global} ? 'global' : '') . 'projectnumber';
  my $description_column = ($params{global} ? 'global' : '') . 'project';

  my $object = $entry->{object};

  # Check whether or not project ID is valid.
  if ($object->$id_column) {
    if (! _projects_by($self)->{id}->{ $object->$id_column }) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid project');
      return 0;
    } else {
      $entry->{info_data}->{$number_column} = _projects_by($self)->{id}->{ $object->$id_column }->description;
    };
  }

  my $proj;
  # Map number to ID if given.
  if (!$object->$id_column && $entry->{raw_data}->{$number_column}) {
    $proj = _projects_by($self)->{projectnumber}->{ $entry->{raw_data}->{$number_column} };
    if (!$proj) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid project');
      return 0;
    }

    $object->$id_column($proj->id);
  }

  # Map description to ID if given.
  if (!$object->$id_column && $entry->{raw_data}->{$description_column}) {
    $proj = _projects_by($self)->{description}->{ $entry->{raw_data}->{$description_column} };
    if (!$proj) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid project');
      return 0;
    }

    $object->$id_column($proj->id);
  }

  if ( $proj ) {
    $entry->{info_data}->{"$description_column"} = $proj->description;
    $entry->{info_data}->{"$number_column"}      = $proj->projectnumber;
  };

  return 1;
}

sub check_department {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # Check whether or not department ID was assigned and is valid.
  if ($object->department_id) {
    if (!_departments_by($self)->{id}->{ $object->department_id }) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid department');
      return 0;
    } else {
      # add department description as well, more feedback for user
      $entry->{info_data}->{department} = _departments_by($self)->{id}->{ $object->department_id }->description;
    };
  }

  # Map department description to ID if given.
  if (!$object->department_id && $entry->{raw_data}->{department}) {
    $entry->{info_data}->{department} = $entry->{raw_data}->{department};
    my $dep = _departments_by($self)->{description}->{ $entry->{raw_data}->{department} };
    if (!$dep) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid department');
      return 0;
    }
    $entry->{info_data}->{department} = $dep->description;
    $object->department_id($dep->id);
  }

  return 1;
}

# ToDo: salesman by name
sub handle_salesman {
  my ($self, $entry) = @_;

  my $object = $entry->{object};
  my $vc_obj;
  $vc_obj    = SL::DB::Customer->new(id => $object->customer_id)->load if $object->can('customer') && $object->customer_id;
  $vc_obj    = SL::DB::Vendor->new(id   => $object->vendor_id)->load   if (!$vc_obj && $object->can('vendor') && $object->vendor_id);

  # salesman from customer/vendor or login if not given
  if (!$object->salesman) {
    if ($vc_obj && $vc_obj->salesman_id) {
      $object->salesman(SL::DB::Manager::Employee->find_by(id => $vc_obj->salesman_id));
    } else {
      $object->salesman(SL::DB::Manager::Employee->current);
    }
  }
}

# ToDo: employee by name
sub handle_employee {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # employee from front end if not given
  if (!$object->employee_id) {
    $object->employee_id($self->controller->{employee_id});
  }
  # employee from login if not given
  if (!$object->employee_id) {
    $object->employee_id(SL::DB::Manager::Employee->current->id) if SL::DB::Manager::Employee->current;
  }
}



#
# private functions
#

sub _currencies_by {
  my ($self) = @_;

  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ _all_currencies($self) } } ) } qw(id name) };
}

sub _all_currencies {
  my ($self) = @_;

  return SL::DB::Manager::Currency->get_all;
}

sub _default_currency_id {
  my ($self) = @_;

  return SL::DB::Default->get->currency_id;
}

sub _default_taxzone_id {
  my ($self) = @_;

  return SL::DB::Manager::TaxZone->get_all_sorted(query => [ obsolete => 0 ])->[0]->id;
}

sub _departments_by {
  my ($self) = @_;

  my $all_departments = SL::DB::Manager::Department->get_all;
  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ $all_departments } } ) } qw(id description) };
}

sub _projects_by {
  my ($self) = @_;

  my $all_projects = SL::DB::Manager::Project->get_all;
  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ $all_projects } } ) } qw(id projectnumber description) };
}

sub _taxzones_by {
  my ($self) = @_;

  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ _all_taxzones($self) } } ) } qw(id description) };
}

sub _all_taxzones {
  my ($self) = @_;

  return SL::DB::Manager::TaxZone->get_all_sorted(query => [ obsolete => 0 ]);
}

1;
