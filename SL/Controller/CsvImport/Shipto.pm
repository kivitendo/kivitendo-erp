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

  $self->controller->track_progress(phase => 'building data', progress => 0);

  my $i;
  my $num_data = scalar @{ $self->controller->data };
  foreach my $entry (@{ $self->controller->data }) {
    $self->controller->track_progress(progress => $i/$num_data * 100) if $i % 100 == 0;

    $self->check_vc($entry, 'trans_id');
    $entry->{object}->module('CT');
  } continue {
    $i++;
  }

  $self->add_info_columns({ header => $::locale->text('Customer/Vendor'), method => 'vc_name' });
}

sub get_duplicate_check_fields {
  return {
    shiptoname_and_shiptostreet => {
      label     => $::locale->text('Name and Street'),
      default   => 1,
      maker     => sub {
        my $o = shift;
        return join(
                 '--',
                 $o->trans_id,
                 map(
                   { s/[\s,\.\-]//g; $_ }
                   $o->shiptoname,
                   $o->shiptostreet
                 )
        );
      }
    },

    shiptoname => {
      label     => $::locale->text('Name'),
      default   => 1,
      maker     => sub {
        my $o = shift;
        return join(
                 '--',
                 $o->trans_id,
                 map(
                   { s/[\s,\.\-]//g; $_ }
                   $o->shiptoname
                 )
        );
      }
    },

    shiptostreet => {
      label     => $::locale->text('Street'),
      default   => 1,
      maker     => sub {
        my $o = shift;
        return join(
                 '--',
                 $o->trans_id,
                 map(
                   { s/[\s,\.\-]//g; $_ }
                   $o->shiptostreet
                 )
        );
      }
    },
  };
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
