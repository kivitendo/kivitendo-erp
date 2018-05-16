package SL::Controller::CustomerVendor;

use strict;
use parent qw(SL::Controller::Base);

use List::MoreUtils qw(any);

use SL::JSON;
use SL::DBUtils;
use SL::Helper::Flash;
use SL::Locale::String;
use SL::Controller::Helper::GetModels;

use SL::DB::Customer;
use SL::DB::Vendor;
use SL::DB::Business;
use SL::DB::Employee;
use SL::DB::Language;
use SL::DB::TaxZone;
use SL::DB::Note;
use SL::DB::PaymentTerm;
use SL::DB::Pricegroup;
use SL::DB::Contact;
use SL::DB::FollowUp;
use SL::DB::FollowUpLink;
use SL::DB::History;
use SL::DB::Currency;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(customer_models vendor_models) ],
);

# safety
__PACKAGE__->run_before(
  sub {
    $::auth->assert('customer_vendor_edit');
  }
);
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
  ]
);

__PACKAGE__->run_before(
  '_load_customer_vendor',
  only => [
    'edit',
    'show',
    'update',
    'ajaj_get_shipto',
    'ajaj_get_contact',
  ]
);

# make sure this comes after _load_customer_vendor
__PACKAGE__->run_before(
  '_check_customer_vendor_all_edit',
  only => [
    'edit',
    'show',
    'update',
    'delete',
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
  ]
);

__PACKAGE__->run_before(
  '_create_customer_vendor',
  only => [
    'add',
  ]
);

__PACKAGE__->run_before('normalize_name');


sub action_add {
  my ($self) = @_;

  $self->_pre_render();
  $self->{cv}->assign_attributes(hourly_rate => $::instance_conf->get_customer_hourly_rate) if $self->{cv}->is_customer;

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

sub _save {
  my ($self) = @_;

  my @errors = $self->{cv}->validate;
  if (@errors) {
    flash('error', @errors);
    $self->_pre_render();
    $self->render(
      'customer_vendor/form',
      title => ($self->is_vendor() ? t8('Edit Vendor') : t8('Edit Customer')),
      %{$self->{template_args}}
    );
    $::dispatcher->end_request;
  }

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

    $self->{cv}->save(cascade => 1);

    $self->{contact}->cp_cv_id($self->{cv}->id);
    if( $self->{contact}->cp_name ne '' || $self->{contact}->cp_givenname ne '' ) {
      $self->{contact}->save(cascade => 1);
    }

    if( $self->{note}->subject ne '' && $self->{note}->body ne '' ) {

      if ( !$self->{note_followup}->follow_up_date ) {
        $::form->error($::locale->text('Date missing!'));
      }

      $self->{note}->trans_id($self->{cv}->id);
      $self->{note}->save();

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

  if ($::instance_conf->get_feature_experimental && 'oe.pl' eq $script) {
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

  $::auth->assert('sales_all_edit');

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
        satphone satfax project street zipcode city privatphone privatemail birthday
      )
    )
  };

  $data->{contact_cvars} = $self->_prepare_cvar_configs_for_ajaj($self->{contact}->cvars_by_config);

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
  # if something matches, treat that as sole match
  # unfortunately get_models can't do more than one per package atm, so we d it
  # the oldfashioned way.
  if ($::form->{prefer_exact}) {
    my $exact_matches;
    if (1 == scalar @{ $exact_matches = $manager->get_all(
      query => [
        obsolete => 0,
        (salesman_id => SL::DB::Manager::Employee->current->id) x !$::auth->assert('customer_vendor_all_edit', 1),
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
  my $num_args  = 3;

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
    WHERE ct.id = ?';


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

  $self->{note_followup_link}->trans_type($self->is_vendor() ? 'vendor' : 'customer');
  $self->{note_followup_link}->trans_info($self->{cv}->name);

  if ( $::form->{shipto}->{shipto_id} ) {
    $self->{shipto} = SL::DB::Shipto->new(shipto_id => $::form->{shipto}->{shipto_id})->load();
  } else {
    $self->{shipto} = SL::DB::Shipto->new();
  }
  $self->{shipto}->assign_attributes(%{$::form->{shipto}});
  $self->{shipto}->module('CT');

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

  if ( $::form->{contact_id} ) {
    $self->{contact} = SL::DB::Contact->new(cp_id => $::form->{contact_id})->load();

    if ( $self->{contact}->cp_cv_id != $self->{cv}->id ) {
      die($::locale->text('Error'));
    }
  } else {
    $self->{contact} = $self->_new_contact_object;
  }
}

sub _check_customer_vendor_all_edit {
  my ($self) = @_;

  unless ($::auth->assert('customer_vendor_all_edit', 1)) {
    die($::locale->text("You don't have the rights to edit this customer.") . "\n")
      if $self->{cv}->is_customer and
         SL::DB::Manager::Employee->current->id != $self->{cv}->salesman_id;
  };
};

sub _create_customer_vendor {
  my ($self) = @_;

  $self->{cv} = $self->_new_customer_vendor_object;
  $self->{cv}->currency_id($::instance_conf->get_currency_id());

  $self->{note} = SL::DB::Note->new();

  $self->{note_followup} = SL::DB::FollowUp->new();

  $self->{shipto} = SL::DB::Shipto->new();

  $self->{contact} = $self->_new_contact_object;
}

sub _pre_render {
  my ($self) = @_;

  my $dbh = $::form->get_standard_dbh();

  my $query;

  $self->{all_business} = SL::DB::Manager::Business->get_all();

  $self->{all_employees} = SL::DB::Manager::Employee->get_all(query => [ deleted => 0 ]);

  $query =
    'SELECT DISTINCT(greeting)
     FROM customer
     WHERE greeting IS NOT NULL AND greeting != \'\'
     UNION
       SELECT DISTINCT(greeting)
       FROM vendor
       WHERE greeting IS NOT NULL AND greeting != \'\'
     ORDER BY greeting';
  $self->{all_greetings} = [
    map(
      { $_->{greeting}; }
      selectall_hashref_query($::form, $dbh, $query)
    )
  ];

  $query =
    'SELECT DISTINCT(cp_title) AS title
     FROM contacts
     WHERE cp_title IS NOT NULL AND cp_title != \'\'
     ORDER BY cp_title';
  $self->{all_titles} = [
    map(
      { $_->{title}; }
      selectall_hashref_query($::form, $dbh, $query)
    )
  ];

  $self->{all_currencies} = SL::DB::Manager::Currency->get_all();

  $self->{all_languages} = SL::DB::Manager::Language->get_all();

  $self->{all_taxzones} = SL::DB::Manager::TaxZone->get_all_sorted();

  if ( $::instance_conf->get_vertreter() ) {
    $query =
      'SELECT id
       FROM business
       WHERE salesman';
    my $business_ids = [
      map(
        { $_->{id}; }
        selectall_hashref_query($::form, $dbh, $query)
      )
    ];

    if ( $business_ids->[0] ) {
      $self->{all_salesman_customers} = SL::DB::Manager::Customer->get_all(query => [business_id => $business_ids]);
    } else {
      $self->{all_salesman_customers} = [];
    }
  } else {
    $self->{all_salesmen} = SL::DB::Manager::Employee->get_all(query => [ or => [ id => $self->{cv}->salesman_id,  deleted => 0 ] ]);
  }

  $self->{all_payment_terms} = SL::DB::Manager::PaymentTerm->get_all_sorted(where => [ or => [ id       => $self->{cv}->payment_id,
                                                                                               obsolete => 0 ] ]);

  $self->{all_delivery_terms} = SL::DB::Manager::DeliveryTerm->get_all();

  if ($self->{cv}->is_customer) {
    $self->{all_pricegroups} = SL::DB::Manager::Pricegroup->get_all_sorted(query => [ or => [ id => $self->{cv}->pricegroup_id, obsolete => 0 ] ]);
  }

  $query =
    'SELECT DISTINCT(cp_abteilung) AS department
     FROM contacts
     WHERE cp_abteilung IS NOT NULL AND cp_abteilung != \'\'
     ORDER BY cp_abteilung';
  $self->{all_departments} = [
    map(
      { $_->{department}; }
      selectall_hashref_query($::form, $dbh, $query)
    )
  ];

  $self->{contacts} = $self->{cv}->contacts;
  $self->{contacts} ||= [];

  $self->{shiptos} = $self->{cv}->shipto;
  $self->{shiptos} ||= [];

  $self->{notes} = SL::DB::Manager::Note->get_all(
    query => [
      trans_id => $self->{cv}->id,
      trans_module => 'ct',
    ],
    with_objects => ['follow_up'],
  );

  $self->{template_args} ||= {};

  $::request->{layout}->add_javascripts('kivi.CustomerVendor.js');
  $::request->{layout}->add_javascripts('kivi.File.js');

  $self->_setup_form_action_bar;
}

sub _setup_form_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      combobox => [
        action => [
          t8('Save'),
          submit    => [ '#form', { action => "CustomerVendor/save" } ],
          checks    => [ 'check_taxzone_and_ustid' ],
          accesskey => 'enter',
        ],
        action => [
          t8('Save and Close'),
          submit => [ '#form', { action => "CustomerVendor/save_and_close" } ],
          checks => [ 'check_taxzone_and_ustid' ],
        ],
      ], # end of combobox "Save"

      combobox => [
        action => [ t8('Workflow') ],
        (action => [
          t8('Save and AP Transaction'),
          submit => [ '#form', { action => "CustomerVendor/save_and_ap_transaction" } ],
          checks => [ 'check_taxzone_and_ustid' ],
        ]) x !!$self->is_vendor,
        (action => [
          t8('Save and AR Transaction'),
          submit => [ '#form', { action => "CustomerVendor/save_and_ar_transaction" } ],
          checks => [ 'check_taxzone_and_ustid' ],
        ]) x !$self->is_vendor,
        action => [
          t8('Save and Invoice'),
          submit => [ '#form', { action => "CustomerVendor/save_and_invoice" } ],
          checks => [ 'check_taxzone_and_ustid' ],
        ],
        action => [
          t8('Save and Order'),
          submit => [ '#form', { action => "CustomerVendor/save_and_order" } ],
          checks => [ 'check_taxzone_and_ustid' ],
        ],
        (action => [
          t8('Save and RFQ'),
          submit => [ '#form', { action => "CustomerVendor/save_and_rfq" } ],
          checks => [ 'check_taxzone_and_ustid' ],
        ]) x !!$self->is_vendor,
        (action => [
          t8('Save and Quotation'),
          submit => [ '#form', { action => "CustomerVendor/save_and_quotation" } ],
          checks => [ 'check_taxzone_and_ustid' ],
        ]) x !$self->is_vendor,
      ], # end of combobox "Workflow"

      action => [
        t8('Delete'),
        submit   => [ '#form', { action => "CustomerVendor/delete" } ],
        confirm  => t8('Do you really want to delete this object?'),
        disabled => !$self->{cv}->id    ? t8('This object has not been saved yet.')
                  : !$self->is_orphaned ? t8('This object has already been used.')
                  :                       undef,
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
    query => [
     ( salesman_id => SL::DB::Manager::Employee->current->id) x !$::auth->assert('customer_vendor_all_edit', 1),
    ],
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

sub _new_customer_vendor_object {
  my ($self) = @_;

  my $class  = 'SL::DB::' . ($self->is_vendor ? 'Vendor' : 'Customer');
  return $class->new(
    contacts         => [],
    shipto           => [],
    custom_variables => [],
  );
}

sub _new_contact_object {
  my ($self) = @_;

  return SL::DB::Contact->new(custom_variables => []);
}

1;
