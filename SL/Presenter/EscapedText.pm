package SL::Presenter::EscapedText;

use strict;

use JSON ();

use overload '""' => \&escaped;

sub new {
  my ($class, %params) = @_;

  return $params{text} if ref($params{text}) eq $class;

  my $self      = bless {}, $class;
  $self->{text} = $params{is_escaped} ? $params{text} : $::locale->quote_special_chars('HTML', $params{text});

  return $self;
}

sub escaped {
  my ($self) = @_;
  return $self->{text};
}

sub TO_JSON {
  goto &escaped;
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::EscapedText - Thin proxy object around HTML-escaped strings

=head1 SYNOPSIS

  use SL::Presenter::EscapedText;

  sub blackbox {
    my ($text) = @_;
    return SL::Presenter::EscapedText->new(text => $text);
  }

  sub build_output {
    my $output_of_other_component = blackbox('Hello & Goodbye');

    # The following is safe, text will not be escaped twice:
    return SL::Presenter::EscapedText->new(text => $output_of_other_component);
  }

  my $output = build_output();
  print "Yeah: $output\n";

=head1 OVERVIEW

Sometimes it's nice to let a sub-component build its own
representation. However, you always have to be very careful about
whose responsibility escaping is. Only the building function knows
enough about the structure to be able to HTML escape properly.

But higher functions should not have to care if the output is already
escaped -- they should be able to simply escape it again. Without
producing stuff like '&amp;amp;'.

Stringification is overloaded. It will return the same as L<escaped>.

This works together with the template plugin
L<SL::Template::Plugin::P> and its C<escape> method.

=head1 FUNCTIONS

=over 4

=item C<new %params>

Creates an instance of C<EscapedText>.

The parameter C<text> is the text to escape. If it is already an
instance of C<EscapedText> then C<$params{text}> is returned
unmodified.

Otherwise C<text> is HTML-escaped and stored in the new instance. This
can be overridden by setting C<$params{is_escaped}> to a trueish
value.

=item C<escaped>

Returns the escaped string (not an instance of C<EscapedText> but an
actual string).

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
