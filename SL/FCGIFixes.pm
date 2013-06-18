package SL::FCGIFixes;

use strict;

use Encode;
use FCGI;
use version;

# FCGI does not use Perl's I/O layer. Therefore it does not honor
# setting STDOUT to ":utf8" with "binmode".  Also FCGI starting with
# 0.69 implements proper handling for UTF-8 flagged strings -- namely
# by downgrading them into bytes. The combination of the two causes
# kivitendo's way of handling strings to go belly up (storing
# everything in Perl's internal encoding and using Perl's I/O layer
# for automatic conversion on output).
#
# This workaround monkeypatches FCGI's print routine so that all of
# its arguments safe for "$self" are encoded into UTF-8 before calling
# FCGI's original PRINT function.
#
# However, this must not be done if raw I/O is requested -- e.g. when
# sending out binary data. Fortunately that has been centralized via
# Locale's "with_raw_io" function which sets a variable indicating
# that current I/O operations should be raw.

sub fix_print_and_internal_encoding_after_0_68 {
  return if version->new("$FCGI::VERSION")->numify <= version->new("0.68")->numify;

  my $encoder             = Encode::find_encoding('UTF-8');
  my $original_fcgi_print = \&FCGI::Stream::PRINT;

  no warnings 'redefine';

  *FCGI::Stream::PRINT = sub {
    if (!$::locale || !$::locale->raw_io_active) {
      my $self = shift;
      my @vals = map { $encoder->encode("$_", Encode::FB_CROAK|Encode::LEAVE_SRC) } @_;
      @_ = ($self, @vals);
    }

    goto $original_fcgi_print;
  };
}

sub apply_fixes {
  fix_print_and_internal_encoding_after_0_68();
}

1;
