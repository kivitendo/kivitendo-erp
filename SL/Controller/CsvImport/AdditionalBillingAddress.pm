package SL::Controller::CsvImport::AdditionalBillingAddress;

use strict;

use SL::Helper::Csv;

use parent qw(SL::Controller::CsvImport::Base);

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(table) ],
);

sub set_profile_defaults {
};

sub init_class {
  my ($self) = @_;
  $self->class('SL::DB::AdditionalBillingAddress');
}

sub _hash_object {
  my ($o) = @_;
  return join('--', map({ s/[\s,\.\-]//g; $_ } ($o->name, $o->street)));
}

sub check_objects {
  my ($self) = @_;

  $self->controller->track_progress(phase => 'building data', progress => 0);

  my %existing_by_id_name_street = map { (_hash_object($_) => $_) } @{ $self->existing_objects };
  my $methods                    = $self->controller->headers->{methods};

  my $i = 0;
  my $num_data = scalar @{ $self->controller->data };
  foreach my $entry (@{ $self->controller->data }) {
    $self->controller->track_progress(progress => $i/$num_data * 100) if $i % 100 == 0;

    $self->check_vc($entry, 'customer_id');

    next if @{ $entry->{errors} };

    my $object   = $entry->{object};
    my $idx      = _hash_object($object);
    my $existing = $existing_by_id_name_street{$idx};

    if (!$existing) {
      $existing_by_id_name_street{$idx} = $object;
    } else {
      $entry->{object_to_save} = $existing;

      $existing->$_( $object->$_ ) for @{ $methods };

      push @{ $entry->{information} }, $::locale->text('Updating existing entry in database');
    }

  } continue {
    $i++;
  }

  $self->add_info_columns({ header => $::locale->text('Customer/Vendor'), method => 'vc_name' });
}

sub setup_displayable_columns {
  my ($self) = @_;

  $self->SUPER::setup_displayable_columns;

  $self->add_displayable_columns(
    { name => 'default_address', description => $::locale->text('Default address flag') },
    { name => 'name',            description => $::locale->text('Name')                 },
    { name => 'department_1',    description => $::locale->text('Department 1')         },
    { name => 'department_2',    description => $::locale->text('Department 2')         },
    { name => 'street',          description => $::locale->text('Street')               },
    { name => 'zipcode',         description => $::locale->text('Zipcode')              },
    { name => 'city',            description => $::locale->text('City')                 },
    { name => 'country',         description => $::locale->text('Country')              },
    { name => 'contact',         description => $::locale->text('Contact')              },
    { name => 'email',           description => $::locale->text('E-mail')               },
    { name => 'fax',             description => $::locale->text('Fax')                  },
    { name => 'gln',             description => $::locale->text('GLN')                  },
    { name => 'phone',           description => $::locale->text('Phone')                },
    { name => 'customer_id',     description => $::locale->text('Customer')             },
    { name => 'customer',        description => $::locale->text('Customer (name)')      },
    { name => 'customernumber',  description => $::locale->text('Customer Number')      },
  );
}

1;
