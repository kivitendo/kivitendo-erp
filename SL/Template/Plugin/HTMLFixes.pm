package SL::Template::Plugin::HTMLFixes;

use Template::Plugin::HTML;

1;

package Template::Plugin::HTML;

use strict;

use Encode;

# Replacement for Template::Plugin::HTML::url.

# Strings in Lx-Office are stored in Perl's internal encoding but have
# to be output as UTF-8. A normal regex replace doesn't do that
# creating invalid UTF-8 characters upon URL-unescaping.

# The only addition is the "Encode::encode()" line.
no warnings 'redefine';
sub url {
    my ($self, $text) = @_;
    return undef unless defined $text;
    $text =  Encode::encode('utf-8-strict', $text) if $::locale && $::locale->is_utf8;
    $text =~ s/([^a-zA-Z0-9_.-])/uc sprintf("%%%02x",ord($1))/eg;
    return $text;
}

1;
