package SL::DATEV::KNEFile;

use strict;

sub new {
  my $type = shift;
  my $self = {};

  bless $self, $type;

  $self->_init(@_);

  return $self;
}

sub _init {
  my $self   = shift;
  my %params = @_;

  map { $self->{$_} = $params{$_} } keys %params;

  $self->{remaining_bytes} = 250;
  $self->{block_count}     =   0;
  $self->{data}            = '';
}

sub get_data {
  my $self = shift;

  return $self->{data} || '';
}

sub get_block_count {
  my $self = shift;

  return $self->{block_count};
}

sub add_block {
  my $self      = shift;
  my $block     = shift;

  my $block_len = length $block;


  $self->flush() if ($block_len > $self->{remaining_bytes});

  $self->{data}            .= $block;
  $self->{remaining_bytes} -= $block_len;

  return $self;
}

sub flush {
  my $self = shift;

  if (250 == $self->{remaining_bytes}) {
    return $self;
  }

  my $num_zeros             = 6 + $self->{remaining_bytes};
  $self->{data}            .= "\x00" x $num_zeros;

  $self->{remaining_bytes}  = 250;
  $self->{block_count}++;

  return $self;
}

sub format_amount {
  my $self   = shift;
  my $amount = shift;
  my $width  = shift;
  our $stellen;

  $amount =~ s/-//;
  my ($places, $decimal_places) = split m/\./, "$amount";

  $places          *= 1;
  $decimal_places ||= 0;

  if (0 < $width) {
    $width  -= 2;
    $places  = sprintf("\%0${stellen}d", $places);
  }

  $decimal_places .= '0' if (2 > length $decimal_places);
  $amount          = $places . substr($decimal_places, 0, 2);
  $amount         *= 1 if (!$width);

  return $amount;
}

1;
