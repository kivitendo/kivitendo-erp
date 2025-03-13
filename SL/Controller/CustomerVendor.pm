package SL::Controller::CustomerVendor;

use strict;
use parent qw(SL::Controller::Base);

use List::MoreUtils qw(any);

use SL::JSON;
use SL::DBUtils;
use SL::Helper::Flash;
use SL::Locale::String;
use SL::Util qw(trim);
use SL::VATIDNr;
use SL::Webdav;
use SL::ZUGFeRD;
use SL::Controller::Helper::GetModels;
use SL::Controller::Helper::ReportGenerator;
use SL::Controller::Helper::ParseFilter;

use SL::DB::AuthGroup;
use SL::DB::Customer;
use SL::DB::Vendor;
use SL::DB::Business;
use SL::DB::ContactDepartment;
use SL::DB::ContactTitle;
use SL::DB::Employee;
use SL::DB::Greeting;
use SL::DB::Language;
use SL::DB::TaxZone;
use SL::DB::Note;
use SL::DB::PaymentTerm;
use SL::DB::Pricegroup;
use SL::DB::Price;
use SL::DB::Contact;
use SL::DB::FollowUp;
use SL::DB::FollowUpLink;
use SL::DB::History;
use SL::DB::Currency;
use SL::DB::Invoice;
use SL::DB::PurchaseInvoice;
use SL::DB::Order;

use Data::Dumper;

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw(user_has_edit_rights) ],
  'scalar --get_set_init' => [ qw(customer_models vendor_models zugferd_settings) ],
);

# safety
__PACKAGE__->run_before(
  '_instantiate_args',
  only => [
    'save',
    'save_and_ap_transaction',
    'save_and_ar_transaction',
    'save_and_close',
    'save_and_invoice',
    'save_and_order',
    'save_and_quotation',
    'save_and_rfq',
    'delete',
    'delete_contact',
    'delete_shipto',
    'delete_additional_billing_address',
  ]
);

__PACKAGE__->run_before(
  '_load_customer_vendor',
  only => [
    'edit',
    'show',
    'update',
    'ajaj_get_shipto',
    'ajaj_get_additional_billing_address',
    'ajaj_get_contact',
    'ajax_list_prices',
  ]
);

# make sure this comes after _load_customer_vendor
__PACKAGE__->run_before('_check_auth');

__PACKAGE__->run_before(
  '_create_customer_vendor',
  only => [
    'add',
  ]
);

__PACKAGE__->run_before('normalize_name');

my @ADDITIONAL_BILLING_ADDRESS_COLUMNS = qw(name department_1 department_2 contact street zipcode city country gln email phone fax default_address);

sub action_add {
  my ($self) = @_;

  $self->_pre_render();

  if ($self->{cv}->is_customer) {
    $self->{cv}->assign_attributes(hourly_rate => $::instance_conf->get_customer_hourly_rate);
    $self->{cv}->salesman_id(SL::DB::Manager::Employee->current->id) if !$::auth->assert('customer_vendor_all_edit', 1);
  }

  $self->render(
    'customer_vendor/form',
    title => ($self->is_vendor() ? $::locale->text('Add Vendor') : $::locale->text('Add Customer')),
    %{$self->{template_args}}
  );
}

sub action_edit {
  my ($self) = @_;

  $self->_pre_render();
  $self->render(
    'customer_vendor/form',
    title => ($self->is_vendor() ? $::locale->text('Edit Vendor') : $::locale->text('Edit Customer')),
    %{$self->{template_args}}
  );
}

sub action_show {
  my ($self) = @_;

  if ($::request->type eq 'json') {
    my $cv_hash;
    if (!$self->{cv}) {
      # TODO error
    } else {
      $cv_hash          = $self->{cv}->as_tree;
      $cv_hash->{cvars} = $self->{cv}->cvar_as_hashref;
    }

    $self->render(\ SL::JSON::to_json($cv_hash), { layout => 0, type => 'json', process => 0 });
  }
}

sub _check_ustid_taxnumber_unique {
  my ($self) = @_;

  my %cfg;
  if ($self->is_vendor()) {
    %cfg = (should_check  => $::instance_conf->get_vendor_ustid_taxnummer_unique,
            manager_class => 'SL::DB::Manager::Vendor',
            err_ustid     => t8('A vendor with the same VAT ID already exists.'),
            err_taxnumber => t8('A vendor with the same taxnumber already exists.'),
    );

  } elsif ($self->is_customer()) {
    %cfg = (should_check  => $::instance_conf->get_customer_ustid_taxnummer_unique,
            manager_class => 'SL::DB::Manager::Customer',
            err_ustid     => t8('A customer with the same VAT ID already exists.'),
            err_taxnumber => t8('A customer with the same taxnumber already exists.'),
    );

  } else {
    return;
  }

  my @errors;

  if ($cfg{should_check}) {
    my $do_clean_taxnumber = sub { my $n = $_[0]; $n //= ''; $n =~ s{[[:space:].-]+}{}g; return $n};

    my $clean_ustid     = SL::VATIDNr->clean($self->{cv}->ustid);
    my $clean_taxnumber = $do_clean_taxnumber->($self->{cv}->taxnumber);

    if (!($clean_ustid || $clean_taxnumber)) {
      return t8('VAT ID and/or taxnumber must be given.');

    } else {
      my $clean_number = $clean_ustid;
      if ($clean_number) {
        my $entries = $cfg{manager_class}->get_all(query => ['!id' => $self->{cv}->id, '!ustid' => undef, '!ustid' => ''], select => ['ustid'], distinct => 1);
        if (any { $clean_number eq SL::VATIDNr->clean($_->ustid) } @$entries) {
          push @errors, $cfg{err_ustid};
        }
      }

      $clean_number = $clean_taxnumber;
      if ($clean_number) {
        my $entries = $cfg{manager_class}->get_all(query => ['!id' => $self->{cv}->id, '!taxnumber' => undef, '!taxnumber' => ''], select => ['taxnumber'], distinct => 1);
        if (any { $clean_number eq $do_clean_taxnumber->($_->taxnumber) } @$entries) {
          push @errors, $cfg{err_taxnumber};
        }
      }
    }
  }

  return join "\n", @errors if @errors;
  return;
}

sub _save {
  my ($self) = @_;

  my @errors = $self->{cv}->validate;
  if (@errors) {
    flash('error', $_) for @errors;
    $self->_pre_render();
    $self->render(
      'customer_vendor/form',
      title => ($self->is_vendor() ? t8('Edit Vendor') : t8('Edit Customer')),
      %{$self->{template_args}}
    );
    $::dispatcher->end_request;
  }

  $self->{cv}->greeting(trim $self->{cv}->greeting);
  my $save_greeting           = $self->{cv}->greeting
    && $::instance_conf->get_vc_greetings_use_textfield
    && SL::DB::Manager::Greeting->get_all_count(where => [description => $self->{cv}->greeting]) == 0;

  $self->{contact}->cp_title(trim($self->{contact}->cp_title));
  my $save_contact_title      = $self->{contact}->cp_title
    && $::instance_conf->get_contact_titles_use_textfield
    && SL::DB::Manager::ContactTitle->get_all_count(where => [description => $self->{contact}->cp_title]) == 0;

  $self->{contact}->cp_abteilung(trim($self->{contact}->cp_abteilung));
  my $save_contact_department = $self->{contact}->cp_abteilung
    && $::instance_conf->get_contact_departments_use_textfield
    && SL::DB::Manager::ContactDepartment->get_all_count(where => [description => $self->{contact}->cp_abteilung]) == 0;

  my $db = $self->{cv}->db;

  $db->with_transaction(sub {
    my $cvs_by_nr;
    if ( $self->is_vendor() ) {
      if ( $self->{cv}->vendornumber ) {
        $cvs_by_nr = SL::DB::Manager::Vendor->get_all(query => [vendornumber => $self->{cv}->vendornumber]);
      }
    } else {
      if ( $self->{cv}->customernumber ) {
        $cvs_by_nr = SL::DB::Manager::Customer->get_all(query => [customernumber => $self->{cv}->customernumber]);
      }
    }

    foreach my $entry (@{$cvs_by_nr}) {
      if( $entry->id != $self->{cv}->id ) {
        my $msg =
          $self->is_vendor() ? $::locale->text('This vendor number is already in use.') : $::locale->text('This customer number is already in use.');

        $::form->error($msg);
      }
    }

    my $ustid_taxnumber_error = $self->_check_ustid_taxnumber_unique;
    $::form->error($ustid_taxnumber_error) if $ustid_taxnumber_error;

    $self->{cv}->save(cascade => 1);

    SL::DB::Greeting->new(description => $self->{cv}->greeting)->save if $save_greeting;

    $self->{contact}->cp_cv_id($self->{cv}->id);
    if( $self->{contact}->cp_name ne '' || $self->{contact}->cp_givenname ne '' ) {
      SL::DB::ContactTitle     ->new(description => $self->{contact}->cp_title)    ->save if $save_contact_title;
      SL::DB::ContactDepartment->new(description => $self->{contact}->cp_abteilung)->save if $save_contact_department;

      $self->{contact}->save(cascade => 1);
    }

    if( $self->{note}->subject ne '' && $self->{note}->body ne '' ) {

      if ( !$self->{note_followup}->follow_up_date ) {
        $::form->error($::locale->text('Date missing!'));
      }
      if (!$self->{note_followup}->{created_for_employees}) {
        $::form->error($::locale->text('You must chose a user.'));
      }

      $self->{note}->trans_id($self->{cv}->id);
      $self->{note}->save();

      if (delete $self->{note_followup}->{not_done}) {
        $self->{note_followup}->done->delete if $self->{note_followup}->done;
      }
      $self->{note_followup}->save();

      $self->{note_followup_link}->follow_up_id($self->{note_followup}->id);
      $self->{note_followup_link}->trans_id($self->{cv}->id);
      $self->{note_followup_link}->save();

      SL::Helper::Flash::flash_later('info', $::locale->text('Follow-Up saved.'));
    }

    $self->{shipto}->trans_id($self->{cv}->id);
    if(any { $self->{shipto}->$_ ne '' } qw(shiptoname shiptodepartment_1 shiptodepartment_2 shiptostreet shiptozipcode shiptocity shiptocountry shiptogln shiptocontact shiptophone shiptofax shiptoemail)) {
      $self->{shipto}->save(cascade => 1);
    }

    if ($self->is_customer && any { $self->{additional_billing_address}->$_ ne '' } grep { $_ ne 'default_address' } @ADDITIONAL_BILLING_ADDRESS_COLUMNS) {
      $self->{additional_billing_address}->customer_id($self->{cv}->id);
      $self->{additional_billing_address}->save(cascade => 1);

      # Make sure only one address per customer has "default address" set.
      if ($self->{additional_billing_address}->default_address) {
        SL::DB::Manager::AdditionalBillingAddress->update_all(
          set   => { default_address => 0, },
          where => [
            customer_id => $self->{cv}->id,
            '!id'       => $self->{additional_billing_address}->id,
          ]);
      }
    }

    my $snumbers = $self->is_vendor() ? 'vendornumber_'. $self->{cv}->vendornumber : 'customernumber_'. $self->{cv}->customernumber;
    SL::DB::History->new(
      trans_id => $self->{cv}->id,
      snumbers => $snumbers,
      employee_id => SL::DB::Manager::Employee->current->id,
      addition => 'SAVED',
    )->save();

    if ( $::form->{delete_notes} ) {
      foreach my $note_id (@{ $::form->{delete_notes} }) {
        my $note = SL::DB::Note->new(id => $note_id)->load();
        if ( $note->follow_up ) {
          if ( $note->follow_up->follow_up_link ) {
            $note->follow_up->follow_up_link->delete(cascade => 'delete');
          }
          $note->follow_up->delete(cascade => 'delete');
        }
        $note->delete(cascade => 'delete');
      }
    }

    1;
  }) || die($db->error);

}

sub action_save {
  my ($self) = @_;

  $self->_save();

  my @redirect_params = (
    action => 'edit',
    id     => $self->{cv}->id,
    db     => ($self->is_vendor() ? 'vendor' : 'customer'),
  );

  if ( $self->{contact}->cp_id ) {
    push(@redirect_params, contact_id => $self->{contact}->cp_id);
  }

  if ( $self->{shipto}->shipto_id ) {
    push(@redirect_params, shipto_id => $self->{shipto}->shipto_id);
  }

  if ( $self->is_customer && $self->{additional_billing_address}->id ) {
    push(@redirect_params, additional_billing_address_id => $self->{additional_billing_address}->id);
  }

  $self->redirect_to(@redirect_params);
}

sub action_save_and_close {
  my ($self) = @_;

  $self->_save();

  my $msg = $self->is_vendor() ? $::locale->text('Vendor saved') : $::locale->text('Customer saved');
  $::form->redirect($msg);
}

sub _transaction {
  my ($self, $script) = @_;

  $::auth->assert('gl_transactions | ap_transactions | ar_transactions'.
                    '| invoice_edit         | vendor_invoice_edit | ' .
                 ' request_quotation_edit | sales_quotation_edit | sales_order_edit    | purchase_order_edit');

  $self->_save();

  my $name = $::form->escape($self->{cv}->name, 1);
  my $db = $self->is_vendor() ? 'vendor' : 'customer';
  my $action = 'add';

  if ('oe.pl' eq $script) {
    $script = 'controller.pl';
    $action = 'Order/' . $action;
  }

  my $url = $self->url_for(
    controller => $script,
    action     => $action,
    vc         => $db,
    $db .'_id' => $self->{cv}->id,
    $db        => $name,
    type       => $::form->{type},
    callback   => $::form->{callback},
  );

  print $::form->redirect_header($url);
}

sub action_save_and_ar_transaction {
  my ($self) = @_;

  $main::auth->assert('ar_transactions');

  $self->_transaction('ar.pl');
}

sub action_save_and_ap_transaction {
  my ($self) = @_;

  $main::auth->assert('ap_transactions');

  $self->_transaction('ap.pl');
}

sub action_save_and_invoice {
  my ($self) = @_;

  if ( $self->is_vendor() ) {
    $::auth->assert('vendor_invoice_edit');
  } else {
    $::auth->assert('invoice_edit');
  }

  $::form->{type} = 'invoice';
  $self->_transaction($self->is_vendor() ? 'ir.pl' : 'is.pl');
}

sub action_save_and_order {
  my ($self) = @_;

  if ( $self->is_vendor() ) {
    $::auth->assert('purchase_order_edit');
  } else {
    $::auth->assert('sales_order_edit');
  }

  $::form->{type} = $self->is_vendor() ? 'purchase_order' : 'sales_order';
  $self->_transaction('oe.pl');
}

sub action_save_and_rfq {
  my ($self) = @_;

  $::auth->assert('request_quotation_edit');

  $::form->{type} = 'request_quotation';
  $self->_transaction('oe.pl');
}

sub action_save_and_quotation {
  my ($self) = @_;

  $::auth->assert('sales_quotation_edit');

  $::form->{type} = 'sales_quotation';
  $self->_transaction('oe.pl');
}

sub action_delete {
  my ($self) = @_;

  my $db = $self->{cv}->db;

  if( !$self->is_orphaned() ) {
    $self->action_edit();
  } else {

    $db->with_transaction(sub {
      $self->{cv}->delete(cascade => 1);

      my $snumbers = $self->is_vendor() ? 'vendornumber_'. $self->{cv}->vendornumber : 'customernumber_'. $self->{cv}->customernumber;
      SL::DB::History->new(
        trans_id => $self->{cv}->id,
        snumbers => $snumbers,
        employee_id => SL::DB::Manager::Employee->current->id,
        addition => 'DELETED',
      )->save();
    }) || die($db->error);

    my $msg = $self->is_vendor() ? $::locale->text('Vendor deleted!') : $::locale->text('Customer deleted!');
    $::form->redirect($msg);
  }

}


sub action_delete_contact {
  my ($self) = @_;

  my $db = $self->{contact}->db;

  if ( !$self->{contact}->cp_id ) {
    SL::Helper::Flash::flash('error', $::locale->text('No contact selected to delete'));
  } else {

    $db->with_transaction(sub {
      if ( $self->{contact}->used ) {
        $self->{contact}->detach();
        $self->{contact}->save();
        SL::Helper::Flash::flash('info', $::locale->text('Contact is in use and was flagged invalid.'));
      } else {
        $self->{contact}->delete(cascade => 1);
        SL::Helper::Flash::flash('info', $::locale->text('Contact deleted.'));
      }

      1;
    }) || die($db->error);

    $self->{contact} = $self->_new_contact_object;
  }

  $self->action_edit();
}

sub action_delete_shipto {
  my ($self) = @_;

  my $db = $self->{shipto}->db;

  if ( !$self->{shipto}->shipto_id ) {
    SL::Helper::Flash::flash('error', $::locale->text('No shipto selected to delete'));
  } else {

    $db->with_transaction(sub {
      if ( $self->{shipto}->used ) {
        $self->{shipto}->detach();
        $self->{shipto}->save(cascade => 1);
        SL::Helper::Flash::flash('info', $::locale->text('Shipto is in use and was flagged invalid.'));
      } else {
        $self->{shipto}->delete(cascade => 1);
        SL::Helper::Flash::flash('info', $::locale->text('Shipto deleted.'));
      }

      1;
    }) || die($db->error);

    $self->{shipto} = SL::DB::Shipto->new();
  }

  $self->action_edit();
}

sub action_delete_additional_billing_address {
  my ($self) = @_;

  my $db = $self->{additional_billing_address}->db;

  if ( !$self->{additional_billing_address}->id ) {
    SL::Helper::Flash::flash('error', $::locale->text('No address selected to delete'));
  } else {
    $db->with_transaction(sub {
      if ( $self->{additional_billing_address}->used ) {
        $self->{additional_billing_address}->detach;
        $self->{additional_billing_address}->save(cascade => 1);
        SL::Helper::Flash::flash('info', $::locale->text('Address is in use and was flagged invalid.'));
      } else {
        $self->{additional_billing_address}->delete(cascade => 1);
        SL::Helper::Flash::flash('info', $::locale->text('Address deleted.'));
      }

      1;
    }) || die($db->error);

    $self->{additional_billing_address} = SL::DB::AdditionalBillingAddress->new;
  }

  $self->action_edit;
}

sub action_search {
  my ($self) = @_;

  my @url_params = (
    controller => 'ct.pl',
    action => 'search',
    db => $self->is_vendor() ? 'vendor' : 'customer',
  );

  if ( $::form->{callback} ) {
    push(@url_params, callback => $::form->{callback});
  }

  $self->redirect_to(@url_params);
}


sub action_search_contact {
  my ($self) = @_;

  my $url = 'ct.pl?action=search_contact&db=customer';

  if ( $::form->{callback} ) {
    $url .= '&callback='. $::form->escape($::form->{callback});
  }

  print $::form->redirect_header($url);
}

sub action_get_delivery {
  my ($self) = @_;

  $::auth->assert('sales_all_edit')    if $self->is_customer();
  $::auth->assert('purchase_all_edit') if $self->is_vendor();

  my $dbh = $::form->get_standard_dbh();

  my ($arap, $db, $qty_sign);
  if ( $self->is_vendor() ) {
    $arap = 'ap';
    $db = 'vendor';
    $qty_sign = ' * -1 AS qty';
  } else {
    $arap = 'ar';
    $db = 'customer';
    $qty_sign = '';
  }

  my $where = ' WHERE 1=1';
  my @values;

  if ( !$self->is_vendor() && $::form->{shipto_id} && $::form->{shipto_id} ne 'all' ) {
    $where .= " AND ${arap}.shipto_id = ?";
    push(@values, $::form->{shipto_id});
  } else {
    $where .= " AND ${arap}.${db}_id = ?";
    push(@values, $::form->{id});
  }

  if ( $::form->{delivery_from} ) {
    $where .= " AND ${arap}.transdate >= ?";
    push(@values, conv_date($::form->{delivery_from}));
  }

  if ( $::form->{delivery_to} ) {
    $where .= " AND ${arap}.transdate <= ?";
    push(@values, conv_date($::form->{delivery_to}));
  }

  my $query =
    "SELECT
       s.shiptoname,
       i.qty ${qty_sign},
       ${arap}.id,
       ${arap}.transdate,
       ${arap}.invnumber,
       ${arap}.ordnumber,
       i.description,
       i.unit,
       i.sellprice,
       oe.id AS oe_id,
       invoice
     FROM ${arap}

     LEFT JOIN shipto s
      ON ". ($arap eq 'ar' ? '(ar.shipto_id = s.shipto_id) ' : '(ap.id = s.trans_id) ') ."

     LEFT JOIN invoice i
       ON ${arap}.id = i.trans_id

     LEFT JOIN parts p
       ON p.id = i.parts_id

     LEFT JOIN oe
       ON (oe.ordnumber = ${arap}.ordnumber AND NOT ${arap}.ordnumber = ''
           AND ". ($arap eq 'ar' ? 'oe.customer_id IS NOT NULL' : 'oe.vendor_id IS NOT NULL') ." )

     ${where}
     ORDER BY ${arap}.transdate DESC LIMIT 15";

  $self->{delivery} = selectall_hashref_query($::form, $dbh, $query, @values);

  $self->render('customer_vendor/get_delivery', { layout => 0 });
}

sub action_ajaj_get_shipto {
  my ($self) = @_;

  my $data = {};
  $data->{shipto} = {
    map(
      {
        my $name = 'shipto'. $_;
        $name => $self->{shipto}->$name;
      }
      qw(_id name department_1 department_2 street zipcode city gln country contact phone fax email)
    )
  };

  $data->{shipto_cvars} = $self->_prepare_cvar_configs_for_ajaj($self->{shipto}->cvars_by_config);

  $self->render(\SL::JSON::to_json($data), { type => 'json', process => 0 });
}

sub action_ajaj_get_additional_billing_address {
  my ($self) = @_;

  my $data = {
    additional_billing_address => {
      map { ($_ => $self->{additional_billing_address}->$_) } ('id', @ADDITIONAL_BILLING_ADDRESS_COLUMNS)
    },
  };

  $self->render(\SL::JSON::to_json($data), { type => 'json', process => 0 });
}

sub action_ajaj_get_contact {
  my ($self) = @_;

  my $data;

  $data->{contact} = {
    map(
      {
        my $name = 'cp_'. $_;

        if ( $_ eq 'birthday' && $self->{contact}->$name ) {
          $name => $self->{contact}->$name->to_lxoffice;
        } else {
          $name => $self->{contact}->$name;
        }
      }
      qw(
        id gender abteilung title position givenname name email phone1 phone2 fax mobile1 mobile2
        satphone satfax project street zipcode city privatphone privatemail birthday main
      )
    )
  };

  $data->{contact_cvars} = $self->_prepare_cvar_configs_for_ajaj($self->{contact}->cvars_by_config);

  # avoid two or more main_cp
  my $has_main_cp = grep { $_->cp_main == 1 } @{ $self->{cv}->contacts };
  $data->{contact}->{disable_cp_main} = 1 if ($has_main_cp && !$data->{contact}->{cp_main});

  $self->render(\SL::JSON::to_json($data), { type => 'json', process => 0 });
}

sub action_ajaj_autocomplete {
  my ($self, %params) = @_;

  my ($model, $manager, $number, $matches);

  # first see if this is customer or vendor picking
  if ($::form->{type} eq 'customer') {
     $model   = $self->customer_models;
     $manager = 'SL::DB::Manager::Customer';
     $number  = 'customernumber';
  } elsif ($::form->{type} eq 'vendor')  {
     $model   = $self->vendor_models;
     $manager = 'SL::DB::Manager::Vendor';
     $number  = 'vendornumber';
  } else {
     die "unknown type $::form->{type}";
  }

  # if someone types something, and hits enter, assume he entered the full name.
  # if something matches, treat that as the sole match
  # unfortunately get_models can't do more than one per package atm, so we do it
  # the oldfashioned way.
  if ($::form->{prefer_exact}) {
    my $exact_matches;
    if (1 == scalar @{ $exact_matches = $manager->get_all(
      query => [
        obsolete => 0,
        or => [
          name    => { ilike => $::form->{filter}{'all:substr:multi::ilike'} },
          $number => { ilike => $::form->{filter}{'all:substr:multi::ilike'} },
        ]
      ],
      limit => 2,
    ) }) {
      $matches = $exact_matches;
    }
  }

  $matches //= $model->get;

  my @hashes = map {
   +{
     value       => $_->displayable_name,
     label       => $_->displayable_name,
     id          => $_->id,
     $number     => $_->$number,
     name        => $_->name,
     type        => $::form->{type},
     cvars       => { map { ($_->config->name => { value => $_->value_as_text, is_valid => $_->is_valid }) } @{ $_->cvars_by_config } },
    }
  } @{ $matches };

  $self->render(\ SL::JSON::to_json(\@hashes), { layout => 0, type => 'json', process => 0 });
}

sub action_test_page {
  $_[0]->render('customer_vendor/test_page');
}

sub action_ajax_list_prices {
  my ($self, %params) = @_;

  my $report   = SL::ReportGenerator->new(\%::myconfig, $::form);
  my @columns  = qw(partnumber description price);
  my @visible  = qw(partnumber description price);
  my @sortable = qw(partnumber description price);

  my %column_defs = (
    partnumber  => { text => $::locale->text('Part Number'),      sub => sub { $_[0]->parts->partnumber  } },
    description => { text => $::locale->text('Part Description'), sub => sub { $_[0]->parts->description } },
    price       => { text => $::locale->text('Price'),            sub => sub { $::form->format_amount(\%::myconfig, $_[0]->price, 2) }, align => 'right' },
  );

  $::form->{sort_by}  ||= 'partnumber';
  $::form->{sort_dir} //= 1;

  for my $col (@sortable) {
    $column_defs{$col}{link} = $self->url_for(
      action   => 'ajax_list_prices',
      callback => $::form->{callback},
      db       => $::form->{db},
      id       => $self->{cv}->id,
      sort_by  => $col,
      sort_dir => ($::form->{sort_by} eq $col ? 1 - $::form->{sort_dir} : $::form->{sort_dir})
    );
  }

  map { $column_defs{$_}{visible} = 1 } @visible;

  my $pricegroup;
  $pricegroup = $self->{cv}->pricegroup->pricegroup if $self->{cv}->pricegroup;

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_options(allow_pdf_export => 0, allow_csv_export => 0);
  $report->set_sort_indicator($::form->{sort_by}, $::form->{sort_dir});
  $report->set_export_options(@{ $params{report_generator_export_options} || [] });
  $report->set_options(
    %{ $params{report_generator_options} || {} },
    output_format        => 'HTML',
    top_info_text        => $::locale->text('Pricegroup') . ': ' . $pricegroup,
    title                => $::locale->text('Price List'),
  );

  my $sort_param = $::form->{sort_by} eq 'price'       ? 'price'             :
                   $::form->{sort_by} eq 'description' ? 'parts.description' :
                   'parts.partnumber';
  $sort_param .= ' ' . ($::form->{sort_dir} ? 'ASC' : 'DESC');
  my $prices = SL::DB::Manager::Price->get_all(where        => [ pricegroup_id => $self->{cv}->pricegroup_id ],
                                               sort_by      => $sort_param,
                                               with_objects => 'parts');

  $self->report_generator_list_objects(report => $report, objects => $prices, layout => 0, header => 0);
}

# open the dialog for customer/vendor details
# called from SL::Presenter::customer_vendor
sub action_show_customer_vendor_details_dialog {
  my ($self) = @_;

  my $is_customer = 'customer' eq $::form->{cv};
  my $cv;
  if ($is_customer) {
    $cv = SL::DB::Customer->new(id => $::form->{cv_id})->load;
  } else {
    $cv = SL::DB::Vendor->new(id => $::form->{cv_id})->load;
  }

  my %details = map { $_ => $cv->$_ } @{$cv->meta->columns};
  $details{discount_as_percent} = $cv->discount_as_percent;
  $details{creditlimt}          = $cv->creditlimit_as_number;
  $details{business}            = $cv->business->description      if $cv->business;
  $details{language}            = $cv->language_obj->description  if $cv->language_obj;
  $details{delivery_terms}      = $cv->delivery_term->description if $cv->delivery_term;
  $details{payment_terms}       = $cv->payment->description       if $cv->payment;
  $details{pricegroup}          = $cv->pricegroup->pricegroup     if $is_customer && $cv->pricegroup;

  if ($is_customer) {
    foreach my $entry (@{ $cv->additional_billing_addresses }) {
      push @{ $details{ADDITIONAL_BILLING_ADDRESSES} },   { map { $_ => $entry->$_ } @{$entry->meta->columns} };
    }
  }
  foreach my $entry (@{ $cv->shipto }) {
    push @{ $details{SHIPTO} },   { map { $_ => $entry->$_ } @{$entry->meta->columns} };
  }
  foreach my $entry (@{ $cv->contacts }) {
    push @{ $details{CONTACTS} }, { map { $_ => $entry->$_ } @{$entry->meta->columns} };
  }

  $_[0]->render('common/show_vc_details', { layout => 0 },
                is_customer => $is_customer,
                %details);

}

sub is_vendor {
  return $::form->{db} eq 'vendor';
}

sub is_customer {
  return $::form->{db} eq 'customer';
}

sub is_orphaned {
  my ($self) = @_;

  if ( defined($self->{_is_orphaned}) ) {
    return $self->{_is_orphaned};
  }

  my $arap      = $self->is_vendor ? 'ap' : 'ar';
  my $num_args  = 4;

  my $cv = $self->is_vendor ? 'vendor' : 'customer';

  my $query =
   'SELECT a.id
    FROM '. $arap .' AS a
    JOIN '. $cv .' ct ON (a.'. $cv .'_id = ct.id)
    WHERE ct.id = ?

    UNION

    SELECT a.id
    FROM oe a
    JOIN '. $cv .' ct ON (a.'. $cv .'_id = ct.id)
    WHERE ct.id = ?

    UNION

    SELECT a.id
    FROM delivery_orders a
    JOIN '. $cv .' ct ON (a.'. $cv .'_id = ct.id)
    WHERE ct.id = ?

    UNION

    SELECT id
    FROM price_rule_items
    WHERE type LIKE \''. $cv .'\' AND value_int = ?';


  if ( $self->is_vendor ) {
    $query .=
     ' UNION
      SELECT 1 FROM makemodel mm WHERE mm.make = ?';
    $num_args++;
  }

  my ($dummy) = selectrow_query($::form, $::form->get_standard_dbh(), $query, (conv_i($self->{cv}->id)) x $num_args);

  return $self->{_is_orphaned} = !$dummy;
}

sub _copy_form_to_cvars {
  my ($self, %params) = @_;

  foreach my $cvar (@{ $params{target}->cvars_by_config }) {
    my $value = $params{source}->{$cvar->config->name};
    $value    = $::form->parse_amount(\%::myconfig, $value) if $cvar->config->type eq 'number';

    $cvar->value($value);
  }
}

sub _instantiate_args {
  my ($self) = @_;

  my $curr_employee = SL::DB::Manager::Employee->current;

  if ( $::form->{cv}->{id} ) {
    if ( $self->is_vendor() ) {
      $self->{cv} = SL::DB::Vendor->new(id => $::form->{cv}->{id})->load();
    } else {
      $self->{cv} = SL::DB::Customer->new(id => $::form->{cv}->{id})->load();
    }
  } else {
    $self->{cv} = $self->_new_customer_vendor_object;
  }
  $self->{cv}->assign_attributes(%{$::form->{cv}});

  if ( $self->is_customer() && $::form->{cv}->{taxincluded_checked} eq '' ) {
    $self->{cv}->taxincluded_checked(undef);
  }

  $self->{cv}->hourly_rate($::instance_conf->get_customer_hourly_rate) if $self->is_customer && !$self->{cv}->hourly_rate;

  if ( $::form->{note}->{id} ) {
    $self->{note} = SL::DB::Note->new(id => $::form->{note}->{id})->load();
    $self->{note_followup} = $self->{note}->follow_up;
    $self->{note_followup_link} = $self->{note_followup}->follow_up_link;

  } else {
    $self->{note} = SL::DB::Note->new();
    $self->{note_followup} = SL::DB::FollowUp->new();
    $self->{note_followup_link} = SL::DB::FollowUpLink->new();
  }

  $self->{note}->assign_attributes(%{$::form->{note}});
  $self->{note}->created_by($curr_employee->id);
  $self->{note}->trans_module('ct');

  $self->{note_followup}->assign_attributes(%{$::form->{note_followup}});
  $self->{note_followup}->note($self->{note});
  $self->{note_followup}->created_by($curr_employee->id);

  if (delete $::form->{note_followup_done}) {
    $self->{note_followup}->done(SL::DB::FollowUpDone->new) if !$self->{note_followup}->done;
    $self->{note_followup}->done->employee_id(SL::DB::Manager::Employee->current->id);
  } else {
    $self->{note_followup}->{not_done} = 1;
  }

  $self->{note_followup_link}->trans_type($self->is_vendor() ? 'vendor' : 'customer');
  $self->{note_followup_link}->trans_info($self->{cv}->name);

  if ( $::form->{shipto}->{shipto_id} ) {
    $self->{shipto} = SL::DB::Shipto->new(shipto_id => $::form->{shipto}->{shipto_id})->load();
  } else {
    $self->{shipto} = SL::DB::Shipto->new();
  }
  $self->{shipto}->assign_attributes(%{$::form->{shipto}});
  $self->{shipto}->module('CT');

  if ($self->is_customer) {
    if ( $::form->{additional_billing_address}->{id} ) {
      $self->{additional_billing_address} = SL::DB::AdditionalBillingAddress->new(id => $::form->{additional_billing_address}->{id})->load;
    } else {
      $self->{additional_billing_address} = SL::DB::AdditionalBillingAddress->new;
    }
    $self->{additional_billing_address}->assign_attributes(%{ $::form->{additional_billing_address} });
  }

  if ( $::form->{contact}->{cp_id} ) {
    $self->{contact} = SL::DB::Contact->new(cp_id => $::form->{contact}->{cp_id})->load();
  } else {
    $self->{contact} = $self->_new_contact_object;
  }
  $self->{contact}->assign_attributes(%{$::form->{contact}});

  $self->_copy_form_to_cvars(target => $self->{cv},      source => $::form->{cv_cvars});
  $self->_copy_form_to_cvars(target => $self->{contact}, source => $::form->{contact_cvars});
  $self->_copy_form_to_cvars(target => $self->{shipto},  source => $::form->{shipto_cvars});
}

sub _load_customer_vendor {
  my ($self) = @_;

  if ( $self->is_vendor() ) {
    $self->{cv} = SL::DB::Vendor->new(id => $::form->{id})->load();
  } else {
    $self->{cv} = SL::DB::Customer->new(id => $::form->{id})->load();
  }

  if ( $::form->{note_id} ) {
    $self->{note} = SL::DB::Note->new(id => $::form->{note_id})->load();
    $self->{note_followup} = $self->{note}->follow_up;
    $self->{note_followup_link} = $self->{note_followup}->follow_up_link;
  } else {
    $self->{note} = SL::DB::Note->new();
    $self->{note_followup} = SL::DB::FollowUp->new();
    $self->{note_followup_link} = SL::DB::FollowUpLink->new();
  }

  if ( $::form->{shipto_id} ) {
    $self->{shipto} = SL::DB::Shipto->new(shipto_id => $::form->{shipto_id})->load();

    if ( $self->{shipto}->trans_id != $self->{cv}->id ) {
      die($::locale->text('Error'));
    }
  } else {
    $self->{shipto} = SL::DB::Shipto->new();
  }

  if ($self->is_customer) {
    if ( $::form->{additional_billing_address_id} ) {
      $self->{additional_billing_address} = SL::DB::AdditionalBillingAddress->new(id => $::form->{additional_billing_address_id})->load;
      die($::locale->text('Error')) if $self->{additional_billing_address}->customer_id != $self->{cv}->id;

    } else {
      $self->{additional_billing_address} = SL::DB::AdditionalBillingAddress->new;
    }
  }

  if ( $::form->{contact_id} ) {
    $self->{contact} = SL::DB::Contact->new(cp_id => $::form->{contact_id})->load();

    if ( $self->{contact}->cp_cv_id != $self->{cv}->id ) {
      die($::locale->text('Error'));
    }
  } else {
    $self->{contact} = $self->_new_contact_object;
  }
}

sub _may_access_action {
  my ($self, $action)   = @_;

  my $is_new            = !$self->{cv} || !$self->{cv}->id;
  my $is_own_customer   = !$is_new
                       && $self->{cv}->is_customer
                       && (SL::DB::Manager::Employee->current->id == $self->{cv}->salesman_id);
  my $has_edit_rights   = $::auth->assert('customer_vendor_all_edit', 1);
  $has_edit_rights    ||= $::auth->assert('customer_vendor_edit',     1) && ($is_new || $is_own_customer);
  my $needs_edit_rights = $action =~ m{^(?:add|save|delete|update)};

  $self->user_has_edit_rights($has_edit_rights);

  return 1 if $has_edit_rights;
  return 0 if $needs_edit_rights;
  return 1;
}

sub _check_auth {
  my ($self, $action) = @_;

  if (!$self->_may_access_action($action)) {
    $::auth->deny_access;
  }
}

sub _create_customer_vendor {
  my ($self) = @_;

  $self->{cv} = $self->_new_customer_vendor_object;
  $self->{cv}->currency_id($::instance_conf->get_currency_id());

  $self->{note} = SL::DB::Note->new();

  $self->{note_followup} = SL::DB::FollowUp->new();

  $self->{shipto} = SL::DB::Shipto->new();
  $self->{additional_billing_address} = SL::DB::AdditionalBillingAddress->new if $self->is_customer;

  $self->{contact} = $self->_new_contact_object;
}

sub _pre_render {
  my ($self) = @_;

  my $dbh = $::form->get_standard_dbh();

  my $query;

  $self->{all_business} = SL::DB::Manager::Business->get_all();

  $self->{all_employees}   = SL::DB::Manager::Employee->get_all_sorted(query => [ deleted => 0 ]);
  $self->{all_auth_groups} = SL::DB::Manager::AuthGroup->get_all_sorted;

  $self->{all_greetings} = SL::DB::Manager::Greeting->get_all_sorted();
  if ($self->{cv}->id && $self->{cv}->greeting && !grep {$self->{cv}->greeting eq $_->description} @{$self->{all_greetings}}) {
    unshift @{$self->{all_greetings}}, (SL::DB::Greeting->new(description => $self->{cv}->greeting));
  }

  $self->{all_contact_titles} = SL::DB::Manager::ContactTitle->get_all_sorted();
  foreach my $contact (@{ $self->{cv}->contacts }) {
    if ($contact->cp_title && !grep {$contact->cp_title eq $_->description} @{$self->{all_contact_titles}}) {
      unshift @{$self->{all_contact_titles}}, (SL::DB::ContactTitle->new(description => $contact->cp_title));
    }
  }

  $self->{all_contact_departments} = SL::DB::Manager::ContactDepartment->get_all_sorted();
  foreach my $contact (@{ $self->{cv}->contacts }) {
    if ($contact->cp_abteilung && !grep {$contact->cp_abteilung eq $_->description} @{$self->{all_contact_departments}}) {
      unshift @{$self->{all_contact_departments}}, (SL::DB::ContactDepartment->new(description => $contact->cp_abteilung));
    }
  }

  $self->{all_currencies} = SL::DB::Manager::Currency->get_all();

  $self->{all_languages} = SL::DB::Manager::Language->get_all();

  $self->{all_taxzones} = SL::DB::Manager::TaxZone->get_all_sorted();

  $self->{all_salesmen} = SL::DB::Manager::Employee->get_all(query => [ or => [ id => $self->{cv}->salesman_id,  deleted => 0 ] ]);

  $self->{all_payment_terms} = SL::DB::Manager::PaymentTerm->get_all_sorted(where => [ or => [ id       => $self->{cv}->payment_id,
                                                                                               obsolete => 0 ] ]);

  $self->{all_delivery_terms} = SL::DB::Manager::DeliveryTerm->get_all();

  if ($self->{cv}->is_customer) {
    $self->{all_pricegroups} = SL::DB::Manager::Pricegroup->get_all_sorted(query => [ or => [ id => $self->{cv}->pricegroup_id, obsolete => 0 ] ]);
  }

  $self->{contacts} = $self->{cv}->contacts;
  $self->{contacts} ||= [];

  $self->{shiptos} = $self->{cv}->shipto;
  $self->{shiptos} ||= [];

  if ($self->is_customer) {
    $self->{additional_billing_addresses} = $self->{cv}->additional_billing_addresses;
    $self->{additional_billing_addresses} ||= [];
  }

  $self->{notes} = SL::DB::Manager::Note->get_all(
    query => [
      trans_id => $self->{cv}->id,
      trans_module => 'ct',
    ],
    with_objects => ['follow_up'],
  );

  if ( $self->is_vendor()) {
    $self->{open_items} = SL::DB::Manager::PurchaseInvoice->get_all_count(
      query => [
        vendor_id => $self->{cv}->id,
        paid => {lt_sql => 'amount'},
      ],
    );
  } else {
    $self->{open_items} = SL::DB::Manager::Invoice->get_all_count(
      query => [
        customer_id => $self->{cv}->id,
        paid => {lt_sql => 'amount'},
      ],
    );
  }

  if ( $self->is_vendor() ) {
    $self->{open_orders} = SL::DB::Manager::Order->get_all_count(
      query => [
        vendor_id => $self->{cv}->id,
        closed => 'F',
      ],
    );
  } else {
    $self->{open_orders} = SL::DB::Manager::Order->get_all_count(
      query => [
        customer_id => $self->{cv}->id,
        closed => 'F',
      ],
    );
  }

  if ($self->{cv}->number && $::instance_conf->get_webdav) {
    my $webdav = SL::Webdav->new(
      type     => $self->is_customer ? 'customer'
                : $self->is_vendor   ? 'vendor'
                : undef,
      number   => $self->{cv}->number,
    );
    my @all_objects = $webdav->get_all_objects;
    @{ $self->{template_args}->{WEBDAV} } = map { { name => $_->filename,
                                                    type => t8('File'),
                                                    link => File::Spec->catfile($_->full_filedescriptor),
                                                } } @all_objects;
  }

  $self->{template_args} ||= {};

  $::request->{layout}->add_javascripts("$_.js") for qw (kivi.CustomerVendor kivi.File chart kivi.CustomerVendorTurnover follow_up);

  $self->_setup_form_action_bar;
}

sub _setup_form_action_bar {
  my ($self) = @_;

  my $no_rights = $self->user_has_edit_rights ? undef
                : $self->{cv}->is_customer    ? t8("You don't have the rights to edit this customer.")
                :                               t8("You don't have the rights to edit this vendor.");

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      combobox => [
        action => [
          t8('Save'),
          submit    => [ '#form', { action => "CustomerVendor/save" } ],
          checks    => [ 'check_taxzone_and_ustid' ],
          accesskey => 'enter',
          disabled  => $no_rights,
        ],
        action => [
          t8('Save and Close'),
          submit => [ '#form', { action => "CustomerVendor/save_and_close" } ],
          checks => [ 'check_taxzone_and_ustid' ],
          disabled => $no_rights,
        ],
      ], # end of combobox "Save"

      combobox => [
        action => [ t8('Workflow') ],
        (action => [
          t8('Save and AP Transaction'),
          submit => [ '#form', { action => "CustomerVendor/save_and_ap_transaction" } ],
          checks => [ 'check_taxzone_and_ustid' ],
          disabled => $no_rights,
        ]) x !!$self->is_vendor,
        (action => [
          t8('Save and AR Transaction'),
          submit => [ '#form', { action => "CustomerVendor/save_and_ar_transaction" } ],
          checks => [ 'check_taxzone_and_ustid' ],
          disabled => $no_rights,
        ]) x !$self->is_vendor,
        action => [
          t8('Save and Invoice'),
          submit => [ '#form', { action => "CustomerVendor/save_and_invoice" } ],
          checks => [ 'check_taxzone_and_ustid' ],
          disabled => $no_rights,
        ],
        action => [
          t8('Save and Order'),
          submit => [ '#form', { action => "CustomerVendor/save_and_order" } ],
          checks => [ 'check_taxzone_and_ustid' ],
          disabled => $no_rights,
        ],
        (action => [
          t8('Save and RFQ'),
          submit => [ '#form', { action => "CustomerVendor/save_and_rfq" } ],
          checks => [ 'check_taxzone_and_ustid' ],
          disabled => $no_rights,
        ]) x !!$self->is_vendor,
        (action => [
          t8('Save and Quotation'),
          submit => [ '#form', { action => "CustomerVendor/save_and_quotation" } ],
          checks => [ 'check_taxzone_and_ustid' ],
          disabled => $no_rights,
        ]) x !$self->is_vendor,
      ], # end of combobox "Workflow"

      action => [
        t8('Delete'),
        submit   => [ '#form', { action => "CustomerVendor/delete" } ],
        confirm  => t8('Do you really want to delete this object?'),
        disabled => !$self->{cv}->id    ? t8('This object has not been saved yet.')
                  : !$self->is_orphaned ? t8('This object has already been used.')
                  :                       $no_rights,
      ],

      'separator',

      action => [
        t8('History'),
        call     => [ 'kivi.CustomerVendor.showHistoryWindow', $self->{cv}->id ],
        disabled => !$self->{cv}->id ? t8('This object has not been saved yet.') : undef,
      ],
    );
  }
}

sub _prepare_cvar_configs_for_ajaj {
  my ($self, $cvars) = @_;

  return {
    map {
      my $cvar   = $_;
      my $result = { type => $cvar->config->type };

      if ($cvar->config->type eq 'number') {
        $result->{value} = $::form->format_amount(\%::myconfig, $cvar->value, -2);

      } elsif ($result->{type} eq 'date') {
        $result->{value} = $cvar->value ? $cvar->value->to_kivitendo : undef;

      } elsif ($result->{type} =~ m{customer|vendor|part}) {
        my $object       = $cvar->value;
        my $method       = $result->{type} eq 'part' ? 'description' : 'name';

        $result->{id}    = int($cvar->number_value) || undef;
        $result->{value} = $object ? $object->$method // '' : '';

      } else {
        $result->{value} = $cvar->value;
      }

      ( $cvar->config->name => $result )

    } grep { $_->is_valid } @{ $cvars }
  };
}

sub normalize_name {
  my ($self) = @_;

  # check if feature is enabled (select normalize_vc_names from defaults)
  return unless ($::instance_conf->get_normalize_vc_names);

  return unless $self->{cv};
  my $name = $self->{cv}->name;
  $name =~ s/\s+$//;
  $name =~ s/^\s+//;
  $name =~ s/\s+/ /g;
  $self->{cv}->name($name);
}

sub home_address_for_google_maps {
  my ($self)  = @_;

  my $address = $::instance_conf->get_address // '';
  $address    =~ s{^\s+|\s+$|\r+}{}g;
  $address    =~ s{\n+}{,}g;
  $address    =~ s{\s+}{ }g;

  return $address;
}

sub init_customer_models {
  my ($self) = @_;

  SL::Controller::Helper::GetModels->new(
    controller   => $self,
    model        => 'Customer',
    sorted => {
      _default  => {
        by => 'customernumber',
        dir  => 1,
      },
      customernumber => t8('Customer Number'),
    },
  );
}

sub init_vendor_models {
  my ($self) = @_;

  SL::Controller::Helper::GetModels->new(
    controller => $self,
    model      => 'Vendor',
    sorted => {
      _default  => {
        by => 'vendornumber',
        dir  => 1,
      },
      vendornumber => t8('Vendor Number'),
    },
  );
}

sub init_zugferd_settings {
  return [
    [ -1, t8('Use settings from client configuration') ],
    @SL::ZUGFeRD::customer_settings,
  ],
}

sub _new_customer_vendor_object {
  my ($self) = @_;

  my $class  = 'SL::DB::' . ($self->is_vendor ? 'Vendor' : 'Customer');
  my $object = $class->new(
    contacts         => [],
    shipto           => [],
    custom_variables => [],
  );

  $object->additional_billing_addresses([]) if $self->is_customer;

  return $object;
}

sub _new_contact_object {
  my ($self) = @_;

  return SL::DB::Contact->new(custom_variables => []);
}

1;
