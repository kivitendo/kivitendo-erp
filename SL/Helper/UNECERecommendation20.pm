package SL::Helper::UNECERecommendation20;

use strict;
use warnings;
use utf8;

use Exporter qw(import);
our @EXPORT_OK = qw(map_name_to_alpha_2_code);

use List::Util qw(first);

my @mappings = (
  # space and time
  # areas
  [ 'MTK', qr{^(?:m²|qm|quadrat *meter|quadrat *metre)$}i ],

  # distances
  [ 'CMT', qr{^(?:cm|centi *meter|centi *metre)$}i ],
  [ 'MTR', qr{^(?:m|meter|metre)$}i ],
  [ 'KMT', qr{^(?:km|kilo *meter|kilo *metre)$}i ],

  # durations
  [ 'SEC', qr{^(?:s|sec|second|sek|sekunde)$}i ],
  [ 'MIN', qr{^min(?:ute)?$}i ],
  [ 'HUR', qr{^(?:h(?:our)?|std(?:unde)?)$}i ],
  [ 'DAY', qr{^(?:day|tag)$}i ],
  [ 'WEE', qr{^(?:week|woche)$}i ],
  [ 'MON', qr{^mon(?:th|at|atlich)?$}i ],
  [ 'QAN', qr{^quart(?:er|al|alsweise)?$}i ],
  [ 'ANN', qr{^(?:yearly|annually|jährlich|Jahr)?$}i ],

  # mass
  [ 'MGM', qr{^(?:mg|milli *gramm?)$}i ],
  [ 'GRM', qr{^(?:g|gramm?)$}i ],
  [ 'KGM', qr{^(?:kg|kilo *gramm?)$}i ],
  [ 'KTN', qr{^(?:t|tonne|kilo *tonne)$}i ],

  # volumes
  [ 'MLT', qr{^(?:ml|milli *liter|milli *litre)$}i ],
  [ 'LTR', qr{^(?:l|liter|litre)$}i ],

  # digital information
  [ 'C37', qr{^(?:kbit|kilobit?)$}i ],
  [ 'D36', qr{^(?:mbit|megabit?)$}i ],
  [ 'B68', qr{^(?:gbit|gigabit?)$}i ],
  [ 'AD', qr{^(?:b|byte)$}i ],
  [ '2P', qr{^(?:kb|kilobyte)$}i ],
  [ '4L', qr{^(?:mb|megabyte)$}i ],
  [ 'E34', qr{^(?:gb|gigabyte)$}i ],
  [ 'E35', qr{^(?:tb|terabyte)$}i ],
  [ 'E36', qr{^(?:pb|petabyte)$}i ],
  
  # miscellaneous
  [ 'C62', qr{^(?:stck|stück|pieces?|pc|psch|pauschal|licenses?|lizenz(?:en)?)$}i ],
);

sub map_name_to_code {
  my ($unit) = @_;

  return undef if ($unit // '') eq '';

  my $code = first { $unit =~ $_->[1] } @mappings;
  return $code->[0] if $code;

  no warnings 'once';
  $::lxdebug->message(LXDebug::WARN(), "UNECERecommendation20::map_name_code: no mapping found for '$unit'");

  return undef;
}

1;
