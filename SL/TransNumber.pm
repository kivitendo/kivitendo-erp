package SL::TransNumber;

use strict;

use parent qw(Rose::Object);

use Carp;
use List::MoreUtils qw(any none);
use SL::DBUtils;
use SL::PrefixedNumber;
use SL::DB;

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(type id number save dbh dbh_provided business_id) ],
);

my @SUPPORTED_TYPES = qw(invoice invoice_for_advance_payment final_invoice credit_note customer vendor sales_delivery_order purchase_delivery_order sales_order purchase_order sales_quotation request_quotation part service assembly assortment letter);

sub new {
  my $class = shift;
  my $self  = $class->SUPER::new(@_);

  croak "Invalid type " . $self->type if none { $_ eq $self->type } @SUPPORTED_TYPES;

  $self->dbh_provided($self->dbh);
  $self->dbh(SL::DB->client->dbh) if !$self->dbh;
  $self->save(1) unless defined $self->save;
  $self->business_id(undef) if $self->type ne 'customer';

  return $self;
}

sub _get_filters {
  my $self    = shift;

  my $type    = $self->type;
  my %filters = ( where => '' );

  if (any { $_ eq $type } qw(invoice invoice_for_advance_payment final_invoice credit_note)) {
    $filters{trans_number}  = "invnumber";
    $filters{numberfield}   = $type eq 'credit_note' ? "cnnumber" : "invnumber";
    $filters{table}         = "ar";

  } elsif (any { $_ eq $type } qw(customer vendor)) {
    $filters{trans_number}  = "${type}number";
    $filters{numberfield}   = "${type}number";
    $filters{table}         = $type;

  } elsif ($type =~ /_delivery_order$/) {
    $filters{trans_number}  = "donumber";
    $filters{numberfield}   = $type eq 'sales_delivery_order' ? "sdonumber" : "pdonumber";
    $filters{table}         = "delivery_orders";
    $filters{where}         = $type =~ /^sales/ ? '(customer_id IS NOT NULL)' : '(vendor_id IS NOT NULL)';

  } elsif ($type =~ /_order$/) {
    $filters{trans_number}  = "ordnumber";
    $filters{numberfield}   = $type eq 'sales_order' ? "sonumber" : "ponumber";
    $filters{table}         = "oe";
    $filters{where}         = 'NOT COALESCE(quotation, FALSE)';
    $filters{where}        .= $type =~ /^sales/ ? ' AND (customer_id IS NOT NULL)' : ' AND (vendor_id IS NOT NULL)';

  } elsif ($type =~ /_quotation$/) {
    $filters{trans_number}  = "quonumber";
    $filters{numberfield}   = $type eq 'sales_quotation' ? "sqnumber" : "rfqnumber";
    $filters{table}         = "oe";
    $filters{where}         = 'COALESCE(quotation, FALSE)';
    $filters{where}        .= $type =~ /^sales/ ? ' AND (customer_id IS NOT NULL)' : ' AND (vendor_id IS NOT NULL)';

  } elsif ($type =~ /^(part|service|assembly|assortment)$/) {
    $filters{trans_number}  = "partnumber";
    my %numberfield_hash = ( service    => 'servicenumber',
                             assembly   => 'assemblynumber',
                             assortment => 'assortmentnumber',
                             part       => 'articlenumber'
                           );
    $filters{numberfield}   = $numberfield_hash{$type};
    $filters{table}         = "parts";
  } elsif ($type =~ /letter/) {
    $filters{trans_number}  = "letternumber";
    $filters{numberfield}   = "letternumber";
    $filters{table}         = "letter";
  }

  return %filters;
}

sub is_unique {
  my $self = shift;

  return undef if !$self->number;

  my %filters = $self->_get_filters();

  my @where;
  my @values = ($self->number);

  push @where, $filters{where} if $filters{where};

  if ($self->id) {
    push @where,  qq|id <> ?|;
    push @values, conv_i($self->id);
  }

  my $where_str = @where ? ' AND ' . join(' AND ', map { "($_)" } @where) : '';
  my $query     = <<SQL;
    SELECT $filters{trans_number}
    FROM $filters{table}
    WHERE ($filters{trans_number} = ?)
      $where_str
    LIMIT 1
SQL
  my ($existing_number) = selectfirst_array_query($main::form, $self->dbh, $query, @values);

  return $existing_number ? 0 : 1;
}

sub create_unique {
  my $self    = shift;

  my $form    = $main::form;
  my %filters = $self->_get_filters();
  my $number;

  SL::DB->client->with_transaction(sub {
    my $where = $filters{where} ? ' WHERE ' . $filters{where} : '';
    my $query = <<SQL;
      SELECT DISTINCT $filters{trans_number}, 1 AS in_use
      FROM $filters{table}
      $where
SQL

    do_query($form, $self->dbh, "LOCK TABLE " . $filters{table}) || die $self->dbh->errstr;
    my %numbers_in_use = selectall_as_map($form, $self->dbh, $query, $filters{trans_number}, 'in_use');

    my $business_number;
    ($business_number) = selectfirst_array_query($form, $self->dbh, qq|SELECT customernumberinit FROM business WHERE id = ? FOR UPDATE|, $self->business_id) if $self->business_id;
    $number         = $business_number;
    ($number)          = selectfirst_array_query($form, $self->dbh, qq|SELECT $filters{numberfield} FROM defaults FOR UPDATE|)                               if !$number;
    if ($filters{numberfield} eq 'assemblynumber' and length($number) < 1) {
      $filters{numberfield} = 'articlenumber';
      ($number)        = selectfirst_array_query($form, $self->dbh, qq|SELECT $filters{numberfield} FROM defaults FOR UPDATE|)                               if !$number;
    }
    $number          ||= '';
    my $sequence       = SL::PrefixedNumber->new(number => $number);

    do {
      $number = $sequence->get_next;
    } while ($numbers_in_use{$number});

    if ($self->save) {
      if ($self->business_id && $business_number) {
        do_query($form, $self->dbh, qq|UPDATE business SET customernumberinit = ? WHERE id = ?|, $number, $self->business_id);
      } else {
        do_query($form, $self->dbh, qq|UPDATE defaults SET $filters{numberfield} = ?|, $number);
      }
    }

    1;
  }) or do { die SL::DB->client->error };

  return $number;
}

1;
