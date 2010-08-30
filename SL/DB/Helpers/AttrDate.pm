package SL::DB::Helpers::AttrDate;

use strict;

use Carp;
use English;

sub define {
  my $package     = shift;
  my $attribute   = shift;
  my %params      = @_;

  $params{places} = 2 if !defined($params{places});

  my $code        = <<CODE;
package ${package};

sub ${attribute}_as_date {
  my \$self = shift;

  if (scalar \@_) {
    if (\$_[0]) {
      my (\$yy, \$mm, \$dd) = \$::locale->parse_date(\\\%::myconfig, \@_);
      \$self->${attribute}(DateTime->new(year => \$yy, month => \$mm, day => \$dd));
    } else {
      \$self->${attribute}(undef);
    }
  }

  return \$self->${attribute} ? \$::locale->reformat_date({ dateformat => 'yy-mm-dd' }, \$self->${attribute}->ymd, \$::myconfig{dateformat}) : undef;
}

1;
CODE

  eval $code;
  croak "Defining '${attribute}_as_number' failed: $EVAL_ERROR" if $EVAL_ERROR;

  return 1;
}

1;
