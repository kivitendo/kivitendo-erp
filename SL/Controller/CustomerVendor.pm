package SL::Controller::CustomerVendor;

use strict;
use parent qw(SL::Controller::Base);

use SL::JSON;
use SL::DBUtils;
use SL::Helper::Flash;

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
    'delete_contact',
    'delete_shipto',
  ]
);

__PACKAGE__->run_before(
  '_load_customer_vendor',
  only => [
    'edit',
    'update',
    'ajaj_get_shipto',
    'ajaj_get_contact',
  ]
);
__PACKAGE__->run_before(
  '_create_customer_vendor',
  only => [
    'add',
  ]
);

sub action_add {
  my ($self) = @_;

  $self->_pre_render();
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

sub _save {
  my ($self) = @_;

  my $cvs_by_nr;
  if ( $self->is_vendor() ) {
    if ( $self->{cv}->vendornumber ) {
      $cvs_by_nr = SL::DB::Manager::Vendor->get_all(query => [vendornumber => $self->{cv}->vendornumber]);
    }
  }
  else {
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
    $self->{contact}->save();
  }

  if( $self->{note}->subject ne '' && $self->{note}->body ne '' ) {
    $self->{note}->trans_id($self->{cv}->id);
    $self->{note}->save();
    $self->{note_followup}->save();

    $self->{note} = SL::DB::Note->new();
    $self->{note_followup} = SL::DB::FollowUp->new();
  }

  $self->{shipto}->trans_id($self->{cv}->id);
  if( $self->{shipto}->shiptoname ne '' ) {
    $self->{shipto}->save();
  }

  #TODO: history
}

sub action_save {
  my ($self) = @_;

  $self->_save();

  $self->action_edit();
}

sub action_save_and_close {
  my ($self) = @_;

  $self->_save();

  my $msg = $self->is_vendor() ? $::locale->text('Vendor saved') : $::locale->text('Customer saved');
  $::form->redirect($msg);
}

sub _transaction {
  my ($self, $script) = @_;

  $::auth->assert('general_ledger         | invoice_edit         | vendor_invoice_edit | ' .
                 ' request_quotation_edit | sales_quotation_edit | sales_order_edit    | purchase_order_edit');

  $self->_save();

  my $callback = $::form->escape($::form->{callback}, 1);
  my $name = $::form->escape($self->{cv}->name, 1);
  my $db = $self->is_vendor() ? 'vendor' : 'customer';

  my $url =
    $script .'?'.
    'action=add&'.
    'vc='. $db .'&'.
    $db .'_id=' . $self->{cv}->id .'&'.
    $db .'='. $name .'&'.
    'type='. $::form->{type} .'&'.
    'callback='. $callback;

  print $::form->redirect_header($url);
}

sub action_save_and_ar_transaction {
  my ($self) = @_;

  $main::auth->assert('general_ledger');

  $self->_transaction('ar.pl');
}

sub action_save_and_ap_transaction {
  my ($self) = @_;

  $main::auth->assert('general_ledger');

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

  if( !$self->is_orphaned() ) {
    SL::Helper::Flash::flash('error', $::locale->text('blaabla'));

    $self->action_edit();
  }
  else {
    $self->{cv}->delete();

    #TODO: history

    my $msg = $self->is_vendor() ? $::locale->text('Vendor deleted!') : $::locale->text('Customer deleted!');
    $::form->redirect($msg);
  }

}


sub action_delete_contact {
  my ($self) = @_;

  if ( !$self->{contact}->cp_id ) {
    SL::Helper::Flash::flash('error', $::locale->text('No contact selected to delete'));
  } else {
    if ( $self->{contact}->used ) {
      $self->{contact}->detach();
      $self->{contact}->save();
      SL::Helper::Flash::flash('info', $::locale->text('Contact is in use and was flagged invalid.'));
    } else {
      $self->{contact}->delete();
      SL::Helper::Flash::flash('info', $::locale->text('Contact deleted.'));
    }

    $self->{contact} = SL::DB::Contact->new();
  }

  $self->action_edit();
}

sub action_delete_shipto {
  my ($self) = @_;

  if ( !$self->{shipto}->shipto_id ) {
    SL::Helper::Flash::flash('error', $::locale->text('No shipto selected to delete'));
  } else {
    if ( $self->{shipto}->used ) {
      $self->{shipto}->detach();
      $self->{shipto}->save();
      SL::Helper::Flash::flash('info', $::locale->text('Shipto is in use and was flagged invalid.'));
    } else {
      $self->{shipto}->delete();
      SL::Helper::Flash::flash('info', $::locale->text('Shipto deleted.'));
    }

    $self->{shipto} = SL::DB::Shipto->new();
  }

  $self->action_edit();
}

sub action_get_delivery {
  my ($self) = @_;

  my $dbh = $::form->get_standard_dbh();

  my ($arap, $db, $qty_sign);
  if ( $self->is_vendor() ) {
    $arap = 'ap';
    $db = 'vendor';
    $qty_sign = ' * -1 AS qty';
  }
  else {
    $arap = 'ar';
    $db = 'customer';
    $qty_sign = '';
  }

  my $where = ' WHERE 1=1 ';
  my @values;

  if ( !$self->is_vendor() && $::form->{shipto_id} && $::form->{shipto_id} ne 'all' ) {
    $where .= "AND ${arap}.shipto_id = ?";
    push(@values, $::form->{shipto_id});
  }

  if ( $::form->{delivery_from} ) {
    $where .= "AND ${arap}.transdate >= ?";
    push(@values, conv_date($::form->{delivery_from}));
  }

  if ( $::form->{delivery_to} ) {
    $where .= "AND ${arap}.transdate <= ?";
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
       ON (oe.ordnumber = ${arap}.ordnumber AND NOT ${arap}.ordnumber = '')

     ${where}
     ORDER BY ${arap}.transdate DESC LIMIT 15";

  $self->{delivery} = selectall_hashref_query($::form, $dbh, $query, @values);

  $self->render('customer_vendor/get_delivery', { layout => 0 });
}

sub action_ajaj_get_shipto {
  my ($self) = @_;

  my $data = {
    map(
      {
        my $name = 'shipto'. $_;
        $name => $self->{shipto}->$name;
      }
      qw(_id name department_1 department_2 street zipcode city country contact phone fax email)
    )
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
        }
        else {
          $name => $self->{contact}->$name;
        }
      }
      qw(
        id gender abteilung title position givenname name email phone1 phone2 fax mobile1 mobile2
        satphone satfax project street zipcode city privatphone privatemail birthday
      )
    )
  };

  $data->{contact_cvars} = {
    map(
      {
        if ( $_->config->type eq 'number' ) {
          $_->config->name => $::form->format_amount(\%::myconfig, $_->value, -2);
        }
        else {
          $_->config->name => $_->value;
        }
      }
      grep(
        { $_->is_valid; }
        @{$self->{contact}->cvars_by_config}
      )
    )
  };

  $self->render(\SL::JSON::to_json($data), { type => 'json', process => 0 });
}

sub action_ajaj_customer_autocomplete {
  my ($self, %params) = @_;

  my $limit = $::form->{limit} || 20;
  my $type  = $::form->{type}  || {};
  my $query = { ilike => '%'. $::form->{term} .'%' };

  my @filter;
  push(
    @filter,
    $::form->{column} ? ($::form->{column} => $query) : (or => [ customernumber => $query, name => $query ])
  );

  my $customers = SL::DB::Manager::Customer->get_all(query => [ @filter ], limit => $limit);
  my $value_col = $::form->{column} || 'name';

  my $data = [
    map(
      {
        {
          value => $_->can($value_col)->($_),
          label => $_->displayable_name,
          id    => $_->id,
          customernumber => $_->customernumber,
          name  => $_->name,
        }
      }
      @{$customers}
    )
  ];

  $self->render(\SL::JSON::to_json($data), { layout => 0, type => 'json' });
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
  my $num_args  = 2;

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

sub _instantiate_args {
  my ($self) = @_;

  my $curr_employee = SL::DB::Manager::Employee->current;

  foreach ( 'cv.creditlimit', 'cv.discount' ) {
    my ($namespace, $varname) = split('.', $_, 2);
    $::form->{$namespace}->{$varname} = $::form->parse_amount(\%::myconfig, $::form->{$namespace}->{$varname});
  }
  $::form->{cv}->{discount} /= 100;

  if ( $::form->{cv}->{id} ) {
    if ( $self->is_vendor() ) {
      $self->{cv} = SL::DB::Vendor->new(id => $::form->{cv}->{id})->load();
    }
    else {
      $self->{cv} = SL::DB::Customer->new(id => $::form->{cv}->{id})->load();
    }
  }
  else {
    if ( $self->is_vendor() ) {
      $self->{cv} = SL::DB::Vendor->new();
    }
    else {
      $self->{cv} = SL::DB::Customer->new();
    }
  }
  $self->{cv}->assign_attributes(%{$::form->{cv}});

  foreach my $cvar (@{$self->{cv}->cvars_by_config()}) {
    my $value = $::form->{cv_cvars}->{$cvar->config->name};

    if ( $cvar->config->type eq 'number' ) {
      $value = $::form->parse_amount(\%::myconfig, $value);
    }

    $cvar->value($value);
  }

#  foreach my $cvar_key (keys(%{$::form->{cv_cvars}})) {
#    my $cvar_value = $::form->{cv_cvars}->{$cvar_key};
#    my $cvar = $self->{cv}->cvar_by_name($cvar_key);
#    $cvar->value($cvar_value);
#  }

  if ( $::form->{note}->{id} ) {
    $self->{note} = SL::DB::Note->new(id => $::form->{note}->{id})->load();
  }
  else {
    $self->{note} = SL::DB::Note->new();
  }
  $self->{note}->assign_attributes(%{$::form->{note}});
  $self->{note}->created_by($curr_employee->id);
  $self->{note}->trans_module('ct');
  #  if ( $self->{note}->trans_id != $self->{cv}->id ) {
  #    die($::locale->text('Error'));
  #  }


  $self->{note_followup} = SL::DB::FollowUp->new();
  $self->{note_followup}->assign_attributes(%{$::form->{note_followup}});
  $self->{note_followup}->note($self->{note});
  $self->{note_followup}->created_by($curr_employee->id);

  if ( $::form->{shipto}->{shipto_id} ) {
    $self->{shipto} = SL::DB::Shipto->new(shipto_id => $::form->{shipto}->{shipto_id})->load();
  }
  else {
    $self->{shipto} = SL::DB::Shipto->new();
  }
  $self->{shipto}->assign_attributes(%{$::form->{shipto}});
  $self->{shipto}->module('CT');
#  if ( $self->{shipto}->trans_id != $self->{cv}->id ) {
#    die($::locale->text('Error'));
#  }

  if ( $::form->{contact}->{cp_id} ) {
    $self->{contact} = SL::DB::Contact->new(cp_id => $::form->{contact}->{cp_id})->load();
  }
  else {
    $self->{contact} = SL::DB::Contact->new();
  }
  $self->{contact}->assign_attributes(%{$::form->{contact}});
#  if ( $self->{contact}->cp_cv_id != $self->{cv}->id ) {
#    die($::locale->text('Error'));
#  }

  foreach my $cvar (@{$self->{contact}->cvars_by_config()}) {
    my $value = $::form->{contact_cvars}->{$cvar->config->name};

    if ( $cvar->config->type eq 'number' ) {
      $value = $::form->parse_amount(\%::myconfig, $value);
    }

    $cvar->value($value);
  }
}

sub _load_customer_vendor {
  my ($self) = @_;

  if ( $self->is_vendor() ) {
    $self->{cv} = SL::DB::Vendor->new(id => $::form->{id})->load();
  }
  else {
    $self->{cv} = SL::DB::Customer->new(id => $::form->{id})->load();
  }

  $self->{note} = SL::DB::Note->new();
  $self->{note_followup} = SL::DB::FollowUp->new();

  if ( $::form->{shipto_id} ) {
    $self->{shipto} = SL::DB::Shipto->new(shipto_id => $::form->{shipto_id})->load();

    if ( $self->{shipto}->trans_id != $self->{cv}->id ) {
      die($::locale->text('Error'));
    }
  }
  else {
    $self->{shipto} = SL::DB::Shipto->new();
  }

  if ( $::form->{contact_id} ) {
    $self->{contact} = SL::DB::Contact->new(cp_id => $::form->{contact_id})->load();

    if ( $self->{contact}->cp_cv_id != $self->{cv}->id ) {
      die($::locale->text('Error'));
    }
  }
  else {
    $self->{contact} = SL::DB::Contact->new();
  }
}

sub _create_customer_vendor {
  my ($self) = @_;

  if ( $self->is_vendor() ) {
    $self->{cv} = SL::DB::Vendor->new();
  }
  else {
    $self->{cv} = SL::DB::Customer->new();
  }

  $self->{note} = SL::DB::Note->new();

  $self->{note_followup} = SL::DB::FollowUp->new();

  $self->{shipto} = SL::DB::Shipto->new();

  $self->{contact} = SL::DB::Contact->new();
}

sub _pre_render {
  my ($self) = @_;

  my $dbh = $::form->get_standard_dbh();

  my $query;

  $self->{all_business} = SL::DB::Manager::Business->get_all();

  $self->{all_employees} = SL::DB::Manager::Employee->get_all();

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

  $query =
    'SELECT curr
     FROM defaults';
  my $curr = selectall_hashref_query($::form, $dbh, $query)->[0]->{curr};
  my @currencies = grep(
    { $_; }
    map(
      { s/\s//g; $_; }
      split(m/:/, $curr)
    )
  );
  $self->{all_currencies} = \@currencies;

  $self->{all_languages} = SL::DB::Manager::Language->get_all();

  $self->{all_taxzones} = SL::DB::Manager::TaxZone->get_all();

  #Employee:
  #TODO: ALL_SALESMAN
  #TODO: ALL_SALESMAN_CUSTOMERS

  $self->{all_payment_terms} = SL::DB::Manager::PaymentTerm->get_all();

  $self->{all_pricegroups} = SL::DB::Manager::Pricegroup->get_all();

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

  $self->{template_args} = {};

  $self->{cv}->discount($self->{cv}->discount * 100);


  $::request->{layout}->add_javascripts('autocomplete_customer.js');
}

1;
