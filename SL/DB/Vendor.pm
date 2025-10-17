package SL::DB::Vendor;

use strict;

use Rose::DB::Object::Helpers qw(as_tree);

use SL::Locale::String qw(t8);
use SL::DBUtils ();
use SL::DB::MetaSetup::Vendor;
use SL::DB::Manager::Vendor;
use SL::DB::Helper::IBANValidation;
use SL::DB::Helper::TransNumberGenerator;
use SL::DB::Helper::VATIDNrValidation;
use SL::DB::Helper::CustomerVendorLink (mode => 'vendor');
use SL::DB::Helper::CustomVariables (
  module      => 'CT',
  cvars_alias => 1,
);
use SL::DB::Helper::DisplayableNamePreferences (
  title   => t8('Vendor'),
  options => [ {name => 'vendornumber', title => t8('Vendor Number') },
               {name => 'name',         title => t8('Name')   },
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
    query_args   => [ module  => 'CT' ],
  },
  contacts => {
    type         => 'one to many',
    class        => 'SL::DB::Contact',
    column_map   => { id      => 'cp_cv_id' },
    manager_args => { sort_by => 'lower(contacts.cp_name)' },
  },
  linked_customer_vendor_rel => {
    type       => 'many to many',
    map_class  => 'SL::DB::CustomerVendorLink',
  },
);

__PACKAGE__->meta->initialize;

__PACKAGE__->before_save('_before_save_set_vendornumber');

sub _before_save_set_vendornumber {
  my ($self) = @_;

  $self->create_trans_number if !defined $self->vendornumber || $self->vendornumber eq '';
  return 1;
}

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, $::locale->text('The vendor name is missing.') if !$self->name;
  push @errors, $self->validate_ibans;
  push @errors, $self->validate_vat_id_numbers;

  return @errors;
}

sub is_customer { 0 };
sub is_vendor   { 1 };
sub payment_terms { goto &payment }
sub number { goto &vendornumber }

sub last_used_ap_chart {
  my ($self) = @_;

  my $query = <<EOSQL;
    SELECT c.id
    FROM chart c
    JOIN acc_trans ac ON (ac.chart_id = c.id)
    JOIN ap a         ON (a.id        = ac.trans_id)
    WHERE (a.vendor_id = ?)
      AND (c.category = 'E')
      AND (c.link !~ '_(paid|tax)')
      AND (a.id IN (SELECT max(a2.id) FROM ap a2 WHERE a2.vendor_id = ?))
    ORDER BY ac.acc_trans_id ASC
    LIMIT 1
EOSQL

  my ($chart_id) = SL::DBUtils::selectfirst_array_query($::form, $self->db->dbh, $query, ($self->id) x 2);

  return if !$chart_id;
  return SL::DB::Chart->load_cached($chart_id);
}

1;
