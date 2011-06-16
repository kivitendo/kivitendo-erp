package SL::Controller::CsvImport::Contact;

use strict;

use SL::Helper::Csv;

use parent qw(SL::Controller::CsvImport::Base);

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(table) ],
);

sub init_class {
  my ($self) = @_;
  $self->class('SL::DB::Contact');
}

sub check_objects {
  my ($self) = @_;

  foreach my $entry (@{ $self->controller->data }) {
    $self->check_name($entry);
    $self->check_vc($entry, 'cp_cv_id');
    $self->check_gender($entry);
  }

  $self->add_info_columns({ header => $::locale->text('Customer/Vendor'), method => 'vc_name' });
}

sub check_name {
  my ($self, $entry) = @_;

  my $name     =  $entry->{object}->cp_name;
  $name        =~ s/^\s+//;
  $name        =~ s/\s+$//;

  push @{ $entry->{errors} }, $::locale->text('Error: Name missing') unless $name;
}

sub check_gender {
  my ($self, $entry) = @_;

  push @{ $entry->{errors} }, $::locale->text('Error: Gender (cp_gender) missing or invalid') if ($entry->{object}->cp_gender ne 'm') && ($entry->{object}->cp_gender ne 'f');
}

sub check_duplicates {
  my ($self, %params) = @_;

  my $normalizer = sub { my $name = $_[0]; $name =~ s/[\s,\.\-]//g; return $name; };

  my %by_id_and_name;
  if ('check_db' eq $self->controller->profile->get('duplicates')) {
    foreach my $type (qw(customers vendors)) {
      foreach my $vc (@{ $self->all_vc->{$type} }) {
        $by_id_and_name{ $vc->id } = { map { ( $normalizer->($_->cp_name) => 'db' ) } @{ $vc->contacts } };
      }
    }
  }

  foreach my $entry (@{ $self->controller->data }) {
    next if @{ $entry->{errors} };

    my $name = $normalizer->($entry->{object}->cp_name);

    $by_id_and_name{ $entry->{vc}->id } ||= { };
    if (!$by_id_and_name{ $entry->{vc}->id }->{ $name }) {
      $by_id_and_name{ $entry->{vc}->id }->{ $name } = 'csv';

    } else {
      push @{ $entry->{errors} }, $by_id_and_name{ $entry->{vc}->id }->{ $name } eq 'db' ? $::locale->text('Duplicate in database') : $::locale->text('Duplicate in CSV file');
    }
  }
}

sub field_lengths {
  return ( cp_title     => 75,
           cp_givenname => 75,
           cp_name      => 75,
           cp_phone1    => 75,
           cp_phone2    => 75,
           cp_gender    =>  1,
         );
}

sub setup_displayable_columns {
  my ($self) = @_;

  $self->SUPER::setup_displayable_columns;

  $self->add_displayable_columns({ name => 'cp_abteilung',   description => $::locale->text('Department')                    },
                                 { name => 'cp_birthday',    description => $::locale->text('Birthday')                      },
                                 { name => 'cp_cv_id',       description => $::locale->text('Customer/Vendor (database ID)') },
                                 { name => 'cp_email',       description => $::locale->text('E-mail')                        },
                                 { name => 'cp_fax',         description => $::locale->text('Fax')                           },
                                 { name => 'cp_gender',      description => $::locale->text('Gender')                        },
                                 { name => 'cp_givenname',   description => $::locale->text('Given Name')                    },
                                 { name => 'cp_mobile1',     description => $::locale->text('Mobile1')                       },
                                 { name => 'cp_mobile2',     description => $::locale->text('Mobile2')                       },
                                 { name => 'cp_name',        description => $::locale->text('Name')                          },
                                 { name => 'cp_phone1',      description => $::locale->text('Phone1')                        },
                                 { name => 'cp_phone2',      description => $::locale->text('Phone2')                        },
                                 { name => 'cp_privatemail', description => $::locale->text('Private E-mail')                },
                                 { name => 'cp_privatphone', description => $::locale->text('Private Phone')                 },
                                 { name => 'cp_project',     description => $::locale->text('Project')                       },
                                 { name => 'cp_satfax',      description => $::locale->text('Sat. Fax')                      },
                                 { name => 'cp_satphone',    description => $::locale->text('Sat. Phone')                    },
                                 { name => 'cp_title',       description => $::locale->text('Title')                         },

                                 { name => 'customer',       description => $::locale->text('Customer (name)')               },
                                 { name => 'customernumber', description => $::locale->text('Customer Number')               },
                                 { name => 'vendor',         description => $::locale->text('Vendor (name)')                 },
                                 { name => 'vendornumber',   description => $::locale->text('Vendor Number')                 },
                                );
}

1;
