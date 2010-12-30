package SL::DB::Manager::Invoice;

use strict;

use base qw(SL::DB::Helper::Manager);

sub object_class { 'SL::DB::Invoice' }

__PACKAGE__->make_manager_methods;

sub type_filter {
  my $class = shift;
  my $type  = lc(shift || '');

  return (or  => [ invoice => 0, invoice => undef                                               ]) if $type eq 'ar_transaction';
  return (and => [ invoice => 1, amount  => { ge => 0 }, or => [ storno => 0, storno => undef ] ]) if $type eq 'invoice';
  return (and => [ invoice => 1, amount  => { lt => 0 }, or => [ storno => 0, storno => undef ] ]) if $type eq 'credit_note';
  return (and => [ invoice => 1, amount  => { lt => 0 },         storno => 1                    ]) if $type =~ m/(?:invoice_)?storno/;
  return (and => [ invoice => 1, amount  => { ge => 0 },         storno => 1                    ]) if $type eq 'credit_note_storno';

  die "Unknown type $type";
}

1;
