package SL::Controller::TopQuickSearch::Base;

use strict;
use parent qw(Rose::Object);

sub auth { die 'must be overwritten' }

sub name { die 'must be overwritten' }

sub description_config { die 'must be overwritten' }

sub description_field { die 'must be overwritten' }

sub query_autocomplete { die 'must be overwritten' }

sub select_autocomplete { die 'must be overwritten' }

sub do_search { die 'must be overwritten' }

1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::TopQuickSearch::Base - base interface class for quick search plugins

=head1 DESCRIPTION

see L<SL::Controller::TopQuickSearch>

=head1 INTERFACE

An implementation must provide these functions.

=over 4

=item C<auth>

Must return a string used for access checks. Empty string or undef will mean
unrestricted access.

=item C<name>

Internal name, must be plain ASCII.

=item C<description_config>

Localized name used in the configuration.

=item C<description_field>

Localized name used in the search field as hint. Should fit into an input of
length 20.

=item C<query_autocomplete>

Needs to take C<term> from C<$::form> and must return an arrayref of JSON
serializable matches fit for jquery autocomplete.

=item C<select_autocomplete>

Needs to take C<id> from C<$::form> and must return a redirect string to be
used with C<SL::Controller::Base::redirect_to> pointing to a representation of
the selected object.

=item C<do_search>

Needs to take C<term> from C<$::form> and must return a redirect string to be
used with C<SL::Controller::Base::redirect_to> pointing to a representation of
the search results. If the search will display only only one match, it should
instead return the same result as if that object was selected directly using
C<select_autocomplete>.

=back

=head1 BUGS

None yet :)

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
