package SL::Controller::CsvImport::Project;

use strict;

use SL::Helper::Csv;
use SL::DB::CustomVariable;
use SL::DB::CustomVariableConfig;

use parent qw(SL::Controller::CsvImport::Base);

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(table) ],
);

sub init_class {
  my ($self) = @_;
  $self->class('SL::DB::Project');
}

sub init_all_cvar_configs {
  my ($self) = @_;

  return SL::DB::Manager::CustomVariableConfig->get_all(where => [ module => 'Projects' ]);
}

sub check_objects {
  my ($self) = @_;

  foreach my $entry (@{ $self->controller->data }) {
    $self->handle_cvars($entry);
  }

  $self->add_cvar_raw_data_columns;
}

sub check_duplicates {
  my $self = shift;

  my %duplicates_by_number;

  if ( $self->controller->profile->get('duplicates') eq 'check_db' ) {
    foreach my $object (@{$self->existing_objects}) {
      $duplicates_by_number{$object->{projectnumber}} = 'db';
    }
  }

  foreach my $entry (@{ $self->controller->data }) {

    my $object = $entry->{object};

    if ( $duplicates_by_number{$object->projectnumber()} )
    {
      push( @{$entry->{errors}},
            $duplicates_by_number{$object->projectnumber()} eq 'db' ? $::locale->text('Duplicate in database') : $::locale->text('Duplicate in CSV file')
      );
    } else {
      $duplicates_by_number{$object->projectnumber()} = 'csv';
    }

  }
}

sub setup_displayable_columns {
  my ($self) = @_;

  $self->SUPER::setup_displayable_columns;
  $self->add_cvar_columns_to_displayable_columns;

  $self->add_displayable_columns({ name => 'projectnumber', description => $::locale->text('number') },
                                 { name => 'description',   description => $::locale->text('Description') },
                                 { name => 'active',        description => $::locale->text('Active') },
                                );
}

1;
