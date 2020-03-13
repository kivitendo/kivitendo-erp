package SL::DB::Customer;

use strict;

use Rose::DB::Object::Helpers qw(as_tree);

use SL::Locale::String qw(t8);
use SL::DBUtils ();
use SL::DB::MetaSetup::Customer;
use SL::DB::Manager::Customer;
use SL::DB::Helper::IBANValidation;
use SL::DB::Helper::TransNumberGenerator;
use SL::DB::Helper::VATIDNrValidation;
use SL::DB::Helper::CustomVariables (
  module      => 'CT',
  cvars_alias => 1,
);
use SL::DB::Helper::DisplayableNamePreferences (
  title   => t8('Customer'),
  options => [ {name => 'customernumber', title => t8('Customer Number') },
               {name => 'name',           title => t8('Name')   },
               {name => 'street',         title => t8('Street') },
               {name => 'city',           title => t8('City') },
               {name => 'zipcode',        title => t8('Zipcode')},
               {name => 'email',          title => t8('E-Mail') },
               {name => 'phone',          title => t8('Phone')  }, ]
);

use SL::DB::VC;

__PACKAGE__->meta->add_relationship(
  shipto => {
    type         => 'one to many',
    class        => 'SL::DB::Shipto',
    column_map   => { id      => 'trans_id' },
    manager_args => { sort_by => 'lower(shipto.shiptoname)' },
    query_args   => [ module   => 'CT' ],
  },
  contacts => {
    type         => 'one to many',
    class        => 'SL::DB::Contact',
    column_map   => { id      => 'cp_cv_id' },
    manager_args => { sort_by => 'lower(contacts.cp_name)' },
  },
);

__PACKAGE__->meta->initialize;

__PACKAGE__->before_save('_before_save_set_customernumber');


sub _before_save_set_customernumber {
  my ($self) = @_;

  $self->create_trans_number if !defined $self->customernumber || $self->customernumber eq '';
  return 1;
}

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, $::locale->text('The customer name is missing.') if !$self->name;
  push @errors, $self->validate_ibans;
  push @errors, $self->validate_vat_id_numbers;

  return @errors;
}

sub short_address {
  my ($self) = @_;

  return join ', ', grep { $_ } $self->street, $self->zipcode, $self->city;
}

sub last_used_ar_chart {
  my ($self) = @_;

  my $query = <<EOSQL;
    SELECT c.id
    FROM chart c
    JOIN acc_trans ac ON (ac.chart_id = c.id)
    JOIN ar a ON (a.id = ac.trans_id)
    WHERE (a.customer_id = ?)
      AND (c.category = 'I')
      AND (c.link !~ '_(paid|tax)')
      AND (a.id IN (SELECT max(a2.id) FROM ar a2 WHERE a2.customer_id = ?))
    ORDER BY ac.acc_trans_id ASC
    LIMIT 1
EOSQL

  my ($chart_id) = SL::DBUtils::selectfirst_array_query($::form, $self->db->dbh, $query, ($self->id) x 2);

  return if !$chart_id;
  return SL::DB::Chart->load_cached($chart_id);
}

sub is_customer { 1 };
sub is_vendor   { 0 };
sub payment_terms { goto &payment }
sub number { goto &customernumber }

sub create_zugferd_invoices_for_this_customer {
  my ($self) = @_;

  no warnings 'once';
  return $::instance_conf->get_create_zugferd_invoices if $self->create_zugferd_invoices == -1;
  return $self->create_zugferd_invoices;
}

1;
