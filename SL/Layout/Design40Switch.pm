package SL::Layout::Design40Switch;

use strict;
use parent qw(SL::Layout::Base);

sub is_design40 {
  $::myconfig{stylesheet} =~ /design40/i;
}

sub webpages_path {
  is_design40() ? "templates/design40_webpages" : $_[0]->SUPER::webpages_path
}

sub webpages_fallback_path {
  is_design40() ? "templates/design40_webpages" : $_[0]->SUPER::webpages_fallback_path
}

sub allow_stylesheet_fallback {
  !is_design40();
}

sub html_dialect {
  is_design40() ? 'html5' : $_[0]->SUPER::html_dialect
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Layout::Design40Switch - Layout switch for Design 4.0

=head1 SYNOPSIS

Detects whether the user selected the Design4.0 stylesheet, and if so,
overrides some implementation details.

=head1 DESCRIPTION

Once activated, it will set the templates to use C<templates/design40_webpages> instead.

It will also disable css fallback, so that common.css etc won't interfere.

=head1 BUGS

None yet. :)

=head1 AUTHOR

Sven Schöling $<lt>s.schoeling@googlemail.comE<gt>

=cut
