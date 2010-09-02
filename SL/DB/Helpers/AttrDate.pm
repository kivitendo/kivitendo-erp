package SL::DB::Helpers::AttrDate;

use strict;

use Carp;
use English;

sub define {
  my $package     = shift;
  my $attribute   = shift;
  my %params      = @_;

  no strict 'refs';
  *{ $package . '::' . $attribute . '_as_date' } = sub {
    my ($self, $string) = @_;

    if (@_ > 1) {
      if ($string) {
        my ($yy, $mm, $dd) = $::locale->parse_date(\%::myconfig, $string);
        $self->$attribute(DateTime->new(year => $yy, month => $mm, day => $dd));
      } else {
        $self->$attribute(undef);
      }
    }

    return $self->$attribute
      ? $::locale->reformat_date(
          { dateformat => 'yy-mm-dd' },
          $self->${attribute}->ymd,
          $::myconfig{dateformat}
        )
      : undef;
  };

  return 1;
}

1;
