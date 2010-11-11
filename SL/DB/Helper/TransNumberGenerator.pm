package SL::DB::Helper::TransNumberGenerator;

use strict;

use parent qw(Exporter);
our @EXPORT = qw(get_next_trans_number create_trans_number);

use Carp;
use List::Util qw(max);

use SL::DB::Default;

my $oe_scoping = sub {
  SL::DB::Manager::Order->type_filter($_[0]);
};

my $do_scoping = sub {
  SL::DB::Manager::DeliveryOrder->type_filter($_[0]);
};

my %specs = ( ar                      => { number_column => 'invnumber',                                                             fill_holes_in_range => 1 },
              sales_quotation         => { number_column => 'quonumber', number_range_column => 'sqnumber',  scoping => $oe_scoping,                          },
              sales_order             => { number_column => 'ordnumber', number_range_column => 'sonumber',  scoping => $oe_scoping,                          },
              request_quotation       => { number_column => 'quonumber', number_range_column => 'rfqnumber', scoping => $oe_scoping,                          },
              purchase_order          => { number_column => 'ordnumber', number_range_column => 'ponumber',  scoping => $oe_scoping,                          },
              sales_delivery_order    => { number_column => 'donumber',  number_range_column => 'sdonumber', scoping => $do_scoping, fill_holes_in_range => 1 },
              purchase_delivery_order => { number_column => 'donumber',  number_range_column => 'pdonumber', scoping => $do_scoping, fill_holes_in_range => 1 },
            );

sub get_next_trans_number {
  my ($self, %params) = @_;

  my $spec_type           = $specs{ $self->meta->table } ? $self->meta->table : $self->type;
  my $spec                = $specs{ $spec_type } || croak("Unsupported class " . ref($self));

  my $number_column       = $spec->{number_column};
  my $number              = $self->$number_column;
  my $number_range_column = $spec->{number_range_column} || $number_column;
  my $scoping_conditions  = $spec->{scoping};
  my $fill_holes_in_range = $spec->{fill_holes_in_range};

  return $number if $self->id && $number;

  my $re              = '^(.*?)(\d+)$';
  my %conditions      = $scoping_conditions ? ( query => [ $scoping_conditions->($spec_type) ] ) : ();
  my @numbers         = map { $_->$number_column } @{ $self->_get_manager_class->get_all(%conditions) };
  my %numbers_in_use  = map { ( $_ => 1 )        } @numbers;
  @numbers            = grep { $_ } map { my @matches = m/$re/; @matches ? $matches[-1] * 1 : undef } @numbers;

  my $defaults        = SL::DB::Default->get;
  my $number_range    = $defaults->$number_range_column;
  my @matches         = $number_range =~ m/$re/;
  my $prefix          = (2 != scalar(@matches)) ? ''  : $matches[ 0];
  my $ref_number      = !@matches               ? '1' : $matches[-1];
  my $min_places      = length($ref_number);

  my $new_number      = $fill_holes_in_range ? $ref_number : max($ref_number, @numbers);
  my $new_number_full = undef;

  while (1) {
    $new_number      =  $new_number + 1;
    my $new_number_s =  $new_number;
    $new_number_s    =~ s/\.\d+//g;
    $new_number_full =  $prefix . ('0' x max($min_places - length($new_number_s), 0)) . $new_number_s;
    last if !$numbers_in_use{$new_number_full};
  }

  $defaults->update_attributes($number_range_column => $new_number_full) if $params{update_defaults};
  $self->$number_column($new_number_full)                                if $params{update_record};

  return $new_number_full;
}

sub create_trans_number {
  my ($self, %params) = @_;

  return $self->get_next_trans_number(update_defaults => 1, update_record => 1, %params);
}

1;
