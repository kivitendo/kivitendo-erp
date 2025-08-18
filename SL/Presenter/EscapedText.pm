package SL::Presenter::EscapedText;

use strict;
use Exporter qw(import);
use Scalar::Util qw(looks_like_number);

our @EXPORT_OK = qw(escape is_escaped escape_js escape_js_call);
our %EXPORT_TAGS = (ALL => \@EXPORT_OK);

use JSON ();

use overload '""' => \&escaped_text;

my %html_entities = (
  '<' => '&lt;',
  '>' => '&gt;',
  '&' => '&amp;',
  '"' => '&quot;',
  "'" => '&apos;',
);

# static constructors
sub new {
  my ($class, %params) = @_;

  return $params{text} if ref($params{text}) eq $class;

  my $self      = bless {}, $class;
  $self->{text} = $params{is_escaped} ? $params{text} : quote_html($params{text});

  return $self;
}

sub quote_html {
  return undef unless defined $_[0];
  (my $x = $_[0]) =~ s/(["'<>&])/$html_entities{$1}/ge;
  $x
}

sub escape {
  __PACKAGE__->new(text => $_[0]);
}

sub is_escaped {
  __PACKAGE__->new(text => $_[0], is_escaped => 1);
}

sub escape_js {
  my ($text) = @_;

  $text =~ s|\\|\\\\|g;
  $text =~ s|\'|\\\'|g;
  $text =~ s|\"|\\\"|g;
  $text =~ s|\n|\\n|g;

  __PACKAGE__->new(text => $text, is_escaped => 1);
}

sub escape_js_call {
  my ($func, @args) = @_;

  escape(
      sprintf "%s(%s)",
      escape_js($func),
      join ", ", map {
        looks_like_number($_)
          ? $_
          : '"' . escape_js($_) . '"'
      } @args
  );
}

# internal magic
sub escaped_text {
  my ($self) = @_;
  return $self->{text};
}

sub TO_JSON {
  goto &escaped_text;
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::EscapedText - Thin proxy object to invert the burden of escaping HTML output

=head1 SYNOPSIS

  use SL::Presenter::EscapedText qw(escape is_escaped escape_js);

  sub blackbox {
    my ($text) = @_;
    return SL::Presenter::EscapedText->new(text => $text);

    # or shorter:
    # return escape($text);
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

Stringification is overloaded. It will return the same as L<escaped_text>.

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

=item C<escape $text>

Static constructor, can be exported. Equivalent to calling C<< new(text => $text) >>.

=item C<is_escaped $text>

Static constructor, can be exported. Equivalent to calling C<< new(text => $text, escaped => 1) >>.

=item C<escape_js $text>

Static constructor, can be exported. Like C<escape> but also escapes Javascript.

=item C<escape_js_call $func_name, @args>

Static constructor, can be exported. Used to construct a javascript call than
can be used for onclick handlers in other Presenter functions.

For example:

  L.button_tag(
    P.escape_js_call("kivi.Package.some_func", arg_one, arg_two, arg_three)
    title
  )

=back

=head1 METHODS

=over 4

=item C<escaped_text>

Returns the escaped string (not an instance of C<EscapedText> but an
actual string).

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
