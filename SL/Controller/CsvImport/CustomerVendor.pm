package SL::Controller::CsvImport::CustomerVendor;

use strict;

use SL::Helper::Csv;
use SL::Controller::CsvImport::Helper::Consistency;
use SL::DB::Business;
use SL::DB::CustomVariable;
use SL::DB::CustomVariableConfig;
use SL::DB::Employee;
use SL::DB::PaymentTerm;
use SL::TransNumber;

use parent qw(SL::Controller::CsvImport::Base);

use Rose::Object::MakeMethods::Generic
(
 'scalar --get_set_init' => [ qw(table languages_by businesses_by salesmen_by) ],
);

sub set_profile_defaults {
  my ($self) = @_;
  $self->controller->profile->_set_defaults(table => 'customer');
};

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

sub init_salesmen_by {
  my ($self) = @_;

  return { map { my $col = $_; ( $col => { map { ( lc($_->$col) => $_ ) } @{ SL::DB::Manager::Employee->get_all } } ) } qw(id name login) };
}

sub check_objects {
  my ($self) = @_;

  $self->controller->track_progress(phase => 'building data', progress => 0);

  my $vc            = $self->controller->profile->get('table');
  my $update_policy = $self->controller->profile->get('update_policy') || 'update_existing';
  my $numbercolumn  = "${vc}number";
  my %vcs_by_number = map { ( $_->$numbercolumn => $_ ) } @{ $self->existing_objects };
  my $methods       = $self->controller->headers->{methods};

  my $i = 0;
  my $num_data = scalar @{ $self->controller->data };
  foreach my $entry (@{ $self->controller->data }) {
    $self->controller->track_progress(progress => $i/$num_data * 100) if $i % 100 == 0;
    my $object = $entry->{object};

    $self->check_name($entry);
    $self->check_language($entry);
    $self->check_business($entry);
    $self->check_payment($entry);
    $self->check_delivery_term($entry);
    $self->check_taxzone($entry,  take_default => 1);
    $self->check_currency($entry, take_default => 1);
    $self->check_salesman($entry);
    $self->check_pricegroup($entry) if 'customer' eq $self->table;

    next if @{ $entry->{errors} };

    my @cleaned_fields = $self->clean_fields(qr{[\r\n]}, $object, qw(name department_1 department_2 street zipcode city country gln contact phone fax homepage email cc bcc
                                                                     taxnumber account_number bank_code bank username greeting taxzone));

    push @{ $entry->{information} }, $::locale->text('Illegal characters have been removed from the following fields: #1', join(', ', @cleaned_fields))
      if @cleaned_fields;

    my $existing_vc = $object->$numbercolumn ? $vcs_by_number{ $object->$numbercolumn } : undef;
    if (!$existing_vc) {
      $vcs_by_number{ $object->$numbercolumn } = $object if $object->$numbercolumn;

    } elsif ($update_policy eq 'skip') {
      push(@{$entry->{errors}}, $::locale->text('Skipping due to existing entry in database'));

    } elsif ($update_policy eq 'update_existing') {
      # Update existing customer/vendor records.
      $entry->{object_to_save} = $existing_vc;

      $existing_vc->$_( $entry->{object}->$_ ) for @{ $methods }, keys %{ $self->clone_methods };

      push @{ $entry->{information} }, $::locale->text('Updating existing entry in database');

    } else {
      $object->$numbercolumn('####');
    }

    $self->handle_cvars($entry);

  } continue {
    $i++;
  }

  $self->add_columns(map { "${_}_id" } grep { exists $self->controller->data->[0]->{raw_data}->{$_} } qw(language business payment delivery_term taxzone pricegroup));
  $self->add_cvar_raw_data_columns;
}

sub get_duplicate_check_fields {
  return {
    name => {
      label     => $::locale->text('Customer Name'),
      default   => 1,
      maker     => sub {
        my $name = shift->name;
        $name =~ s/[\s,\.\-]//g;
        return $name;
      }
    },
  };
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

    # register language_id for method copying later
    $self->clone_methods->{language_id} = 1;
  }

  return 1;
}

sub check_business {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # Check whether or not business ID is valid.
  if ($object->business_id && !$self->businesses_by->{id}->{ $object->business_id }) {
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

    # register business_id for method copying later
    $self->clone_methods->{business_id} = 1;
  }

  return 1;
}

sub check_salesman {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # Check whether or not salesman ID is valid.
  if ($object->salesman_id && !$self->salesmen_by->{id}->{ $object->salesman_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid salesman');
    return 0;
  }

  # Map name to ID if given.
  if (!$object->salesman_id && ($entry->{raw_data}->{salesman} || $entry->{raw_data}->{salesman_login})) {
    my $salesman = $self->salesmen_by->{name} ->{ lc($entry->{raw_data}->{salesman}) }
                // $self->salesmen_by->{login}->{ lc($entry->{raw_data}->{salesman_login}) };

    if (!$salesman) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid salesman');
      return 0;
    }

    $object->salesman_id($salesman->id);

    # register salesman_id for method copying later
    $self->clone_methods->{salesman_id} = 1;
  }

  return 1;
}

sub save_objects {
  my ($self, %params) = @_;

  my $numbercolumn   = $self->table . 'number';
  my $with_number    = [ grep { ($_->{object}->$numbercolumn || '') ne '####' } @{ $self->controller->data } ];
  my $without_number = [ grep { ($_->{object}->$numbercolumn || '') eq '####' } @{ $self->controller->data } ];

  $_->{object}->$numbercolumn('') for @{ $without_number };

  $self->SUPER::save_objects(data => $with_number);
  $self->SUPER::save_objects(data => $without_number);
}

sub init_profile {
  my ($self) = @_;

  my $profile = $self->SUPER::init_profile;
  delete @{$profile}{qw(business datevexport language payment delivery_term taxincluded terms)};

  return $profile;
}

sub setup_displayable_columns {
  my ($self) = @_;

  $self->SUPER::setup_displayable_columns;
  $self->add_cvar_columns_to_displayable_columns;

  $self->add_displayable_columns({ name => 'account_number',    description => $::locale->text('Account Number')                  },
                                 { name => 'bank',              description => $::locale->text('Bank')                            },
                                 { name => 'bank_code',         description => $::locale->text('Bank Code')                       },
                                 { name => 'bcc',               description => $::locale->text('Bcc')                             },
                                 { name => 'bic',               description => $::locale->text('BIC')                             },
                                 { name => 'business_id',       description => $::locale->text('Business type (database ID)')     },
                                 { name => 'business',          description => $::locale->text('Business type (name)')            },
                                 { name => 'c_vendor_id',       description => $::locale->text('our vendor number at customer')   },
                                 { name => 'cc',                description => $::locale->text('Cc')                              },
                                 { name => 'city',              description => $::locale->text('City')                            },
                                 { name => 'contact',           description => $::locale->text('Contact')                         },
                                 { name => 'country',           description => $::locale->text('Country')                         },
                                 { name => 'creditlimit',       description => $::locale->text('Credit Limit')                    },
                                 { name => 'currency',          description => $::locale->text('Currency')                        },
                                 { name => 'currency_id',       description => $::locale->text('Currency (database ID)')          },
                                 { name => 'customernumber',    description => $::locale->text('Customer Number')                 },
                                 { name => 'department_1',      description => $::locale->text('Department 1')                    },
                                 { name => 'department_2',      description => $::locale->text('Department 2')                    },
                                 { name => 'delivery_term_id',  description => $::locale->text('Delivery terms (database ID)')    },
                                 { name => 'delivery_term',     description => $::locale->text('Delivery terms (name)')           },
                                 { name => 'direct_debit',      description => $::locale->text('direct debit')                    },
                                 { name => 'discount',          description => $::locale->text('Discount')                        },
                                 { name => 'email',             description => $::locale->text('E-mail')                          },
                                 { name => 'fax',               description => $::locale->text('Fax')                             },
                                 { name => 'gln',               description => $::locale->text('GLN')                             },
                                 { name => 'greeting',          description => $::locale->text('Greeting')                        },
                                 { name => 'homepage',          description => $::locale->text('Homepage')                        },
                                 { name => 'iban',              description => $::locale->text('IBAN')                            },
                                 { name => 'pricegroup_id',     description => $::locale->text('Price group (database ID)')       },
                                 { name => 'pricegroup',        description => $::locale->text('Price group (name)')              },
                                 { name => 'language_id',       description => $::locale->text('Language (database ID)')          },
                                 { name => 'language',          description => $::locale->text('Language (name)')                 },
                                 { name => 'name',              description => $::locale->text('Name')                            },
                                 { name => 'notes',             description => $::locale->text('Notes')                           },
                                 { name => 'obsolete',          description => $::locale->text('Obsolete')                        },
                                 { name => 'payment_id',        description => $::locale->text('Payment terms (database ID)')     },
                                 { name => 'payment',           description => $::locale->text('Payment terms (name)')            },
                                 { name => 'phone',             description => $::locale->text('Phone')                           },
                                 { name => 'salesman',          description => $::locale->text('Salesman')                        },
                                 { name => 'salesman_id',       description => $::locale->text('Salesman (database ID)')          },
                                 { name => 'salesman_login',    description => $::locale->text('Salesman (login)')                },
                                 { name => 'street',            description => $::locale->text('Street')                          },
                                 { name => 'taxnumber',         description => $::locale->text('Tax Number / SSN')                },
                                 { name => 'taxzone',           description => $::locale->text('Tax zone (description)')          },
                                 { name => 'taxzone_id',        description => $::locale->text('Tax zone (database ID)')          },
                                 { name => 'user_password',     description => $::locale->text('Password')                        },
                                 { name => 'username',          description => $::locale->text('Username')                        },
                                 { name => 'ustid',             description => $::locale->text('sales tax identification number') },
                                 { name => 'zipcode',           description => $::locale->text('Zipcode')                         },
                                );
}

# TODO:
# salesman_id -- Kunden mit Typ 'Verkäufer', falls Vertreter-Modus an ist, ansonsten Employees

1;
