package SL::DB::Helpers::AttrPercent;

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

sub ${attribute}_as_percent {
  my \$self = shift;

  if (scalar \@_) {
    \$self->${attribute}(\$::form->parse_amount(\\\%::myconfig, \$_[0]) / 100);
  }

  return \$::form->format_amount(\\\%::myconfig, 100 * \$self->${attribute}, $params{places});
}

1;
CODE

  eval $code;
  croak "Defining '${attribute}_as_number' failed: $EVAL_ERROR" if $EVAL_ERROR;

  return 1;
}

1;
