package SL::Locale::String;

use strict;

use parent qw(Rose::Object Exporter);

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(untranslated) ],
  array  => [ qw(args) ],
);

our @EXPORT = qw(t8);

use overload
  '""' => \&translated,
  eq   => \&my_eq,
  ne   => \&my_ne;

sub translated {
  my ($self) = @_;
  return $::locale ? $::locale->text($self->untranslated, $self->args) : $self->untranslated;
}

sub t8 {
  shift if $_[0] eq __PACKAGE__;

  my $string = shift;
  return SL::Locale::String->new(untranslated => $string, args => [ @_ ]);
}

sub my_eq {
  $_[1] eq $_[0]->translated;
}

sub my_ne {
  $_[1] ne $_[0]->translated;
}

sub TO_JSON {
  return $_[0]->translated;
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::Locale::String - Helper class for translating strings at a later
date (e.g. use at compile time, actual translation during execution
time)

=head1 SYNOPSIS

  use SL::Locale::String;

  use SL::Controller::Helper::Sorted;

  __PACKAGE__->make_sorted(
    ...
    qty => { title => t8("Quantity") },
 );

=head1 OVERVIEW

Every string that should be translated must be recognized by our
translation helper script C<script/locales.pl> somehow. It recognizes
certain function calls as translation instructions and extracts its
arguments for translation by developers/translators.

This works well for calls that occur during execution time: C<<
$::locale->text("Untranslated") >>. However, for untranslated strings
that need to be used at compile time this fails in subtle and not so
subtle ways. If it happens in a module that is C<use>d directly from
the dispatcher then C<$::locale> is not defined and such a call would
end in an error. For modules like controllers that are C<require>d
during execution time it seems to work, but in FastCGI situations this
means that the first call determines the language and all subsequent
calls end up using the same language no matter which language the user
has chosen.

This class solves the issue by providing a small function called L<t8>
which can be used instead of C<< $::locale->text() >>. It is
recognized by C<script/locales.pl>. The untranslated string given to
L<t8> is stored in an instance of C<SL::Locale::String> and translated
only when requested either by calling L<translated> or by
stringification.

Instances of this class can safely be handed over to C<<
$::locale->text() >> which knows how to handle them (and not to
re-translate them).

The function L<t8> is exported by default.

=head1 FUNCTIONS

=head2 EXPORTED FUNCTIONS

=over 4

=item C<t8 $untranslated_string>

Returns a new instance of C<SL::Locale::String> and sets its
L<untranslated> member to C<$untranslated_string>. This function is
exported and cannot be called as a class or instance method.

=back

=head2 INSTANCE FUNCTIONS

=over 4

=item C<untranslated [$new_untranslated]>

Gets or sets the untranslated string.

=item C<translated>

Returns the translated version of the untranslated string. Translation
occurs when this function is called and not when the object instance
is created.

This function is also called during stringification.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
