package SL::Controller::CsvImport::Shipto;

use strict;

use SL::Helper::Csv;

use parent qw(SL::Controller::CsvImport::Base);

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(table) ],
);

sub init_class {
  my ($self) = @_;
  $self->class('SL::DB::Shipto');
}

sub check_objects {
  my ($self) = @_;

  foreach my $entry (@{ $self->controller->data }) {
    $self->check_vc($entry, 'trans_id');
    $entry->{object}->module('CT');
  }

  $self->add_info_columns({ header => $::locale->text('Customer/Vendor'), method => 'vc_name' });
}

sub check_duplicates {
  my ($self, %params) = @_;

  my $normalizer = sub { my $name = $_[0]; $name =~ s/[\s,\.\-]//g; return $name; };
  my $name_maker = sub { return $normalizer->($_[0]->shiptoname) . '--' . $normalizer->($_[0]->shiptostreet) };

  my %by_id_and_name;
  if ('check_db' eq $self->controller->profile->get('duplicates')) {
    foreach my $type (qw(customers vendors)) {
      foreach my $vc (@{ $self->all_vc->{$type} }) {
        $by_id_and_name{ $vc->id } = { map { ( $name_maker->($_) => 'db' ) } @{ $vc->shipto } };
      }
    }
  }

  foreach my $entry (@{ $self->controller->data }) {
    next if @{ $entry->{errors} };

    my $name = $name_maker->($entry->{object});

    $by_id_and_name{ $entry->{vc}->id } ||= { };
    if (!$by_id_and_name{ $entry->{vc}->id }->{ $name }) {
      $by_id_and_name{ $entry->{vc}->id }->{ $name } = 'csv';

    } else {
      push @{ $entry->{errors} }, $by_id_and_name{ $entry->{vc}->id }->{ $name } eq 'db' ? $::locale->text('Duplicate in database') : $::locale->text('Duplicate in CSV file');
    }
  }
}

sub field_lengths {
  return ( shiptoname         => 75,
           shiptodepartment_1 => 75,
           shiptodepartment_2 => 75,
           shiptostreet       => 75,
           shiptozipcode      => 75,
           shiptocity         => 75,
           shiptocountry      => 75,
           shiptocontact      => 75,
           shiptophone        => 30,
           shiptofax          => 30,
         );
}

sub init_profile {
  my ($self) = @_;

  my $profile = $self->SUPER::init_profile;
  delete @{$profile}{qw(module)};

  return $profile;
}

sub setup_displayable_columns {
  my ($self) = @_;

  $self->SUPER::setup_displayable_columns;

  $self->add_displayable_columns({ name => 'shiptocity',         description => $::locale->text('City')                          },
                                 { name => 'shiptocontact',      description => $::locale->text('Contact')                       },
                                 { name => 'shiptocountry',      description => $::locale->text('Country')                       },
                                 { name => 'shiptodepartment_1', description => $::locale->text('Department 1')                  },
                                 { name => 'shiptodepartment_2', description => $::locale->text('Department 2')                  },
                                 { name => 'shiptoemail',        description => $::locale->text('E-mail')                        },
                                 { name => 'shiptofax',          description => $::locale->text('Fax')                           },
                                 { name => 'shiptoname',         description => $::locale->text('Name')                          },
                                 { name => 'shiptophone',        description => $::locale->text('Phone')                         },
                                 { name => 'shiptostreet',       description => $::locale->text('Street')                        },
                                 { name => 'shiptozipcode',      description => $::locale->text('Zipcode')                       },
                                 { name => 'trans_id',           description => $::locale->text('Customer/Vendor (database ID)') },
                                 { name => 'customer',           description => $::locale->text('Customer (name)')               },
                                 { name => 'customernumber',     description => $::locale->text('Customer Number')               },
                                 { name => 'vendor',             description => $::locale->text('Vendor (name)')                 },
                                 { name => 'vendornumber',       description => $::locale->text('Vendor Number')                 },
                                );
}

1;
