package SL::Controller::CsvImport::Project;

use strict;

use SL::Helper::Csv;
use SL::DB::CustomVariable;
use SL::DB::CustomVariableConfig;
use SL::DB::ProjectStatus;
use SL::DB::ProjectType;

use parent qw(SL::Controller::CsvImport::Base);

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(table) ],
 'scalar --get_set_init' => [ qw(project_type_by_description project_status_by_name) ],
);

sub init_class {
  my ($self) = @_;
  $self->class('SL::DB::Project');
}

sub init_project_type_by_description {
  my @a = @{SL::DB::Manager::ProjectType->get_all_sorted};
  my %v = map { +( "$_->{description}" => $_ )} @a;

  return \%v;
}

sub init_project_status_by_name      {
  my @a = @{SL::DB::Manager::ProjectStatus->get_all_sorted};
  my %v =map { +( "$_->{name}"        => $_ )} @a;

  return \%v;
}

sub set_profile_defaults {
};

sub init_all_cvar_configs {
  my ($self) = @_;

  return SL::DB::Manager::CustomVariableConfig->get_all(where => [ module => 'Projects' ]);
}

sub check_objects {
  my ($self) = @_;

  $self->controller->track_progress(phase => 'building data', progress => 0);

  my $i = 0;
  my $num_data = scalar @{ $self->controller->data };
  foreach my $entry (@{ $self->controller->data }) {
    $self->controller->track_progress(progress => $i/$num_data * 100) if $i % 100 == 0;

    $self->check_linked_customer($entry);
    $self->check_project_status($entry);
    $self->check_project_type($entry);
    $self->handle_cvars($entry);
  } continue {
    $i++;
  }

  $self->add_cvar_raw_data_columns;
}

sub check_project_status {
  my ($self, $entry) = @_;

  my $status_obj = $entry->{object}->{project_status_id}
                 ? SL::DB::Manager::ProjectStatus->load_cached($entry->{object}->{project_status_id})
                 : $self->project_status_by_name->{$entry->{raw_data}{project_status}};
  if ($status_obj) {
    $entry->{object}->project_status_id($status_obj->id);
  } else {
    push @{ $entry->{errors} }, $::locale->text('Error: Project status not found');
  }
}

sub check_project_type {
  my ($self, $entry) = @_;

  my $type_obj = $entry->{object}->{project_type_id}
               ? SL::DB::Manager::ProjectType->load_cached($entry->{object}->{project_type_id})
               : $self->project_type_by_description->{$entry->{raw_data}{project_type}};
  if ($type_obj) {
    $entry->{object}->project_type_id($type_obj->id);
  } else {
    push @{ $entry->{errors} }, $::locale->text('Error: Project type not found');
  }
}

sub check_linked_customer {
  my ($self, $entry) = @_;

  my @customer_candidates = grep { defined }
     defined $entry->{raw_data}{customer_id}    ? $self->vc_by->{id}->{ $entry->{raw_data}{customer_id} }                     : undef,
     defined $entry->{raw_data}{customernumber} ? $self->vc_by->{number}->{customers}->{ $entry->{raw_data}{customernumber} } : undef,
     ;

  # sanity check:
  my %seen_customers;
  $seen_customers{$_->id}++ for @customer_candidates;

  if (
    (defined $entry->{raw_data}{customernumber} && $self->vc_counts_by->{number}->{customers}->{ $entry->{raw_data}{customernumber} } > 1) ||
    grep { $_ > 1 } values %seen_customers
  ) {
    push @{ $entry->{errors} }, $::locale->text('Error: Customer is ambiguous');
  }

  if ( !@customer_candidates && (
    $entry->{raw_data}->{customer_id}    ||
    $entry->{raw_data}->{customernumber}
  )) {
    push @{ $entry->{errors} }, $::locale->text('Error: Customer not found');
  }

  # register these in the object to be save in save_additions
  if ($customer_candidates[0]) {
    $entry->{object}->customer_id($customer_candidates[0]->id);
  }
}

sub get_duplicate_check_fields {
  return {
    projectnumber => {
      label     => $::locale->text('Project Number'),
      default   => 1,
      std_check => 1
    },
  };
}

sub setup_displayable_columns {
  my ($self) = @_;

  $self->SUPER::setup_displayable_columns;
  $self->add_cvar_columns_to_displayable_columns;

  $self->add_displayable_columns({ name => 'projectnumber',  description => $::locale->text('number') },
                                 { name => 'customernumber', description => $::locale->text('Customer Number') },
                                 { name => 'description',    description => $::locale->text('Description') },
                                 { name => 'project_type',   description => $::locale->text('Project Type') },
                                 { name => 'project_status', description => $::locale->text('Project Status') },
                                 { name => 'active',         description => $::locale->text('Active') },
                                );
}

1;
