package SL::DB::Helpers::AttrNumber;

use strict;

use Carp;
use English;

sub define {
  my $package     = shift;
  my $attribute   = shift;
  my %params      = @_;

  $params{places} = 2 if !defined($params{places});

  no strict 'refs';
  *{ $package . '::' . $attribute . '_as_number' } = sub {
    my ($self, $string) = @_;

    $self->$attribute($::form->parse_amount(\%::myconfig, $string)) if @_ > 1;

    return $::form->format_amount(\%::myconfig, $self->$attribute, $params{places});
  };

  return 1;
}

1;
