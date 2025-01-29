package SL::Controller::ClientConfig;

use strict;
use parent qw(SL::Controller::Base);

use File::Copy::Recursive ();
use List::Util qw(first);

use SL::DB::Chart;
use SL::DB::Currency;
use SL::DB::Default;
use SL::DB::Language;
use SL::DB::Part;
use SL::DB::Unit;
use SL::DB::Customer;
use SL::Helper::Flash;
use SL::Locale::String qw(t8);
use SL::PriceSource::ALL;
use SL::Template;
use SL::DB::Order::TypeData;
use SL::DB::DeliveryOrder::TypeData;
use SL::DB::Reclamation::TypeData;
use SL::Controller::TopQuickSearch;
use SL::DB::Helper::AccountingPeriod qw(get_balance_startdate_method_options);
use SL::VATIDNr;
use SL::ZUGFeRD;

__PACKAGE__->run_before('check_auth');

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(defaults all_warehouses all_weightunits all_languages all_currencies all_templates all_price_sources h_unit_name available_quick_search_modules
                                  all_project_statuses all_project_types zugferd_settings
                                  posting_options payment_options accounting_options inventory_options profit_options balance_startdate_method_options yearend_options
                                  displayable_name_specs_by_module available_documents_with_no_positions) ],
);

sub action_edit {
  my ($self, %params) = @_;

  $::form->{use_templates} = $self->defaults->templates ? 'existing' : 'new';
  $::form->{feature_datev} = $self->defaults->feature_datev;
  $self->edit_form;
}

sub action_save {
  my ($self, %params)      = @_;

  my $defaults             = delete($::form->{defaults}) || {};
  my $entered_currencies   = delete($::form->{currencies}) || [];
  my $original_currency_id = $self->defaults->currency_id;
  $defaults->{disabled_price_sources} ||= [];

  # undef several fields if an empty value has been selected.
  foreach (qw(warehouse_id bin_id warehouse_id_ignore_onhand bin_id_ignore_onhand)) {
    undef $defaults->{$_} if !$defaults->{$_};
  }

  $self->defaults->assign_attributes(%{ $defaults });

  my %errors_idx;

  # Handle currencies
  my (%new_currency_names);
  foreach my $existing_currency (@{ $self->all_currencies }) {
    my $new_name     = $existing_currency->name;
    my $new_currency = first { $_->{id} == $existing_currency->id } @{ $entered_currencies };
    $new_name        = $new_currency->{name} if $new_currency;

    if (!$new_name) {
      $errors_idx{0} = t8('Currency names must not be empty.');
    } elsif ($new_currency_names{$new_name}) {
      $errors_idx{1} = t8('Currency names must be unique.');
    }

    if ($new_name) {
      $new_currency_names{$new_name} = 1;
      $existing_currency->name($new_name);
    }
  }
  if ($::form->{new_currency} && $new_currency_names{ $::form->{new_currency} }) {
    $errors_idx{1} = t8('Currency names must be unique.');
  }

  my @errors = map { $errors_idx{$_} } sort keys %errors_idx;

  # check valid mail adresses
  foreach (qw(email_sender_sales_quotation email_sender_request_quotation email_sender_sales_order
             email_sender_purchase_order email_sender_sales_delivery_order email_sender_purchase_delivery_order
             email_sender_invoice email_sender_purchase_invoice email_sender_letter email_sender_dunning
             global_bcc)) {
    next unless $defaults->{$_};
    next if     $defaults->{$_} =~ /^[a-z0-9.]+\@[a-z0-9.-]+$/i;
    push @errors, t8('The email entry for #1 looks invalid', $_);
  }
  # Check templates
  $::form->{new_templates}        =~ s:/::g;
  $::form->{new_master_templates} =~ s:/::g;

  if (($::form->{use_templates} eq 'existing') && ($self->defaults->templates !~ m:^templates/[^/]+$:)) {
    push @errors, t8('You must select existing print templates or create a new set.');

  } elsif ($::form->{use_templates} eq 'new') {
    if (!$::form->{new_templates}) {
      push @errors, t8('You must enter a name for your new print templates.');
    } elsif (-d "templates/" . $::form->{new_templates}) {
      push @errors, t8('A directory with the name for the new print templates exists already.');
    } elsif (! -d "templates/print/" . $::form->{new_master_templates}) {
      push @errors, t8('The master templates where not found.');
    }
  }

  my $cleaned_ustid = SL::VATIDNr->clean($defaults->{co_ustid});
  if ($cleaned_ustid && !SL::VATIDNr->validate($cleaned_ustid)) {
    push @errors, t8("The VAT ID number '#1' is invalid.", $defaults->{co_ustid});
  }

  # Show form again if there were any errors. Nothing's been changed
  # yet in the database.
  if (@errors) {
    flash('error', @errors);
    return $self->edit_form;
  }

  # Save currencies. As the names must be unique we cannot simply save
  # them as they are -- the user might want to swap to names. So make
  # them unique first and assign the actual names in a second step.
  my %currency_names_by_id = map { ($_->id => $_->name) } @{ $self->all_currencies };
  $_->update_attributes(name => '__039519735__' . $_->{id})        for @{ $self->all_currencies };
  $_->update_attributes(name => $currency_names_by_id{ $_->{id} }) for @{ $self->all_currencies };

  # Create new currency if required
  my $new_currency;
  if ($::form->{new_currency}) {
    $new_currency = SL::DB::Currency->new(name => $::form->{new_currency});
    $new_currency->save;
  }

  # If the user wants the new currency to be the default then replace
  # the ID placeholder with the proper value. However, if no new
  # currency has been created then don't change the value at all.
  if (-1 == $self->defaults->currency_id) {
    $self->defaults->currency_id($new_currency ? $new_currency->id : $original_currency_id);
  }

  # Create new templates if requested.
  if ($::form->{use_templates} eq 'new') {
    local $File::Copy::Recursive::SkipFlop = 1;
    File::Copy::Recursive::dircopy('templates/print/' . $::form->{new_master_templates}, 'templates/' . $::form->{new_templates});
    $self->defaults->templates('templates/' . $::form->{new_templates});
  }

  # Displayable name preferences
  foreach my $specs (@{ $::form->{displayable_name_specs} }) {
    $self->displayable_name_specs_by_module->{$specs->{module}}->{prefs}->store_default($specs->{default});
  }

  # Finally save defaults.
  $self->defaults->save;

  flash_later('info', t8('Client Configuration saved!'));

  $self->redirect_to(action => 'edit');
}

#
# initializers
#

sub init_defaults        { SL::DB::Default->get                                                                          }
sub init_all_warehouses  { SL::DB::Manager::Warehouse->get_all_sorted                                                    }
sub init_all_languages   { SL::DB::Manager::Language->get_all_sorted                                                     }
sub init_all_currencies  { SL::DB::Manager::Currency->get_all_sorted                                                     }
sub init_all_weightunits { my $unit = SL::DB::Manager::Unit->find_by(name => 'kg'); $unit ? $unit->convertible_units : [] }
sub init_all_templates   { +{ SL::Template->available_templates }                                                        }
sub init_h_unit_name     { first { SL::DB::Manager::Unit->find_by(name => $_) } qw(Std h Stunde)                         }
sub init_all_project_types    { SL::DB::Manager::ProjectType->get_all_sorted                                             }
sub init_all_project_statuses { SL::DB::Manager::ProjectStatus->get_all_sorted                                           }
sub init_zugferd_settings     { \@SL::ZUGFeRD::customer_settings                                                         }

sub init_posting_options {
  [ { title => t8("never"),           value => 0           },
    { title => t8("every time"),      value => 1           },
    { title => t8("on the same day"), value => 2           }, ]
}

sub init_payment_options {
  [ { title => t8("never"),           value => 0           },
    { title => t8("every time"),      value => 1           },
    { title => t8("on the same day"), value => 2           }, ]
}

sub init_accounting_options {
  [ { title => t8("Accrual"),         value => "accrual"   },
    { title => t8("cash"),            value => "cash"      }, ]
}

sub init_inventory_options {
  [ { title => t8("perpetual"),       value => "perpetual" },
    { title => t8("periodic"),        value => "periodic"  }, ]
}

sub init_profit_options {
  [ { title => t8("balance"),         value => "balance"   },
    { title => t8("income"),          value => "income"    }, ]
}

sub init_balance_startdate_method_options {
  return SL::DB::Helper::AccountingPeriod::get_balance_startdate_method_options;
}

sub init_yearend_options {
  [ { title => t8("default"),         value => "default"   },
    { title => t8("simple"),          value => "simple"    }, ]
}

sub init_all_price_sources {
  my @classes = SL::PriceSource::ALL->all_price_sources;

  [ map { [ $_->name, $_->description ] } @classes ];
}

sub init_available_quick_search_modules {
  [ SL::Controller::TopQuickSearch->new->available_modules ];
}

sub init_displayable_name_specs_by_module {
  +{
     'SL::DB::Customer' => {
       specs => SL::DB::Customer->displayable_name_specs,
       prefs => SL::DB::Customer->displayable_name_prefs,
     },
     'SL::DB::Vendor' => {
       specs => SL::DB::Vendor->displayable_name_specs,
       prefs => SL::DB::Vendor->displayable_name_prefs,
     },
     'SL::DB::Part' => {
       specs => SL::DB::Part->displayable_name_specs,
       prefs => SL::DB::Part->displayable_name_prefs,
     },
  };
}

sub init_available_documents_with_no_positions {
  my @docs = ( @{SL::DB::Order::TypeData::valid_types()},
               @{SL::DB::DeliveryOrder::TypeData::valid_types()},
               @{SL::DB::Reclamation::TypeData::valid_types()} );

  my @available_docs = map { {name => $_, description => $::form->get_formname_translation($_)} } @docs;

  return \@available_docs;
}

#
# filters
#

sub check_auth {
  $::auth->assert('admin');
}

#
# helpers
#

sub edit_form {
  my ($self) = @_;

  $::request->layout->use_javascript("${_}.js") for qw(jquery.selectboxes jquery.multiselect2side kivi.File);

  $self->setup_edit_form_action_bar;
  $self->render('client_config/form', title => t8('Client Configuration'),
                make_chart_title     => sub { $_[0]->accno . '--' . $_[0]->description },
                make_templates_value => sub { 'templates/' . $_[0] },
              );
}

sub setup_edit_form_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Save'),
        submit    => [ '#form', { action => 'ClientConfig/save' } ],
        accesskey => 'enter',
      ],
    );
  }
}

1;
