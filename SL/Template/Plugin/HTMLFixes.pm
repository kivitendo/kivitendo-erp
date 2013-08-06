package SL::Template::Plugin::HTMLFixes;

use Template::Plugin::HTML;
use Template::Stash;

1;

package Template::Plugin::HTML;

use strict;

use Encode;

# Replacement for Template::Plugin::HTML::url.

# Strings in kivitendo are stored in Perl's internal encoding but have
# to be output as UTF-8. A normal regex replace doesn't do that
# creating invalid UTF-8 characters upon URL-unescaping.

# The only addition is the "Encode::encode()" line.
no warnings 'redefine';
sub url {
    my ($self, $text) = @_;
    return undef unless defined $text;
    $text =  Encode::encode('utf-8-strict', $text);
    $text =~ s/([^a-zA-Z0-9_.-])/uc sprintf("%%%02x",ord($1))/eg;
    return $text;
}

1;

package Template::Stash;

# A method for forcing list context. If a method uses 'wantarray' then
# calling that method from Template will do strange stuff like chosing
# scalar context. The most obvious offender are RDBO relationships.

# Example of how NOT to test whether or not a customer has contacts:
#   [% IF customer.contacts.size %] ...
# Instead force list context and then test the size:
#   [% IF customer.contacts.as_list.size %] ...
$Template::Stash::LIST_OPS->{ as_list } = sub {
  return ref( $_[0] ) eq 'ARRAY' ? shift : [shift];
};

1;
