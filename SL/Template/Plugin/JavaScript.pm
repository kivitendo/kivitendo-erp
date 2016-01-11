package SL::Template::Plugin::JavaScript;

use base qw( Template::Plugin );
use Template::Plugin;

use strict;

sub new {
  my ($class, $context, @args) = @_;

  return bless {
    CONTEXT => $context,
  }, $class;
}

#
# public interface
#

# see ecmascript spec section 7.8.4
my @escape_chars = ('\\', '\'', '"');
my %control_chars = (
  "\n"   => 'n',
  "\t"   => 't',
  "\r"   => 'r',
  "\f"   => 'f',
  "\x08" => 'b',
  "\x0B" => 'v', # noone uses vertical tab anyway...
);
my $re = join '', map { qr/($_)/s } join '|', keys(%control_chars), map { "\Q$_\E" } @escape_chars;

sub escape {
  my $self = shift;
  my $text = shift;

  $text =~ s/$re/'\\' . ($control_chars{$1} || $1)/egs;

  return $text;
}

sub replace_with {
  return _replace_helper('replaceWith', @_);
}

sub replace_html_with {
  return _replace_helper('html', @_);
}

#
# private methods
#

sub _context {
  die 'not an accessor' if @_ > 1;
  return $_[0]->{CONTEXT};
}

sub _replace_helper {
  my ($method, $self, $selector, $template, $locals) = @_;

  $template .= '.html' unless $template =~ m/\.html$/;
  my $html   = $self->escape($self->_context->process($template, %{ $locals || { } }));
  my $code = <<CODE;
\$('${selector}').${method}("$html");
CODE

  return $code;
}

1;


__END__

=pod

=encoding utf8

=head1 NAME

SL::Template::Plugin::JavaScript - Template plugin for JavaScript helper functions

=head1 FUNCTIONS

=over 4

=item C<escape $value>

Returns C<$value> escaped for inclusion in a JavaScript string. The
value is not wrapped in quotes. Example:

  <input type="submit" value="Delete"
         onclick="if (confirm('Do you really want to delete this: [% JavaScript.escape(obj.description) %]') return true; else return false;">

=item C<replace_with $selector, $template, %locals>

Returns code replacing the DOM elements matched by C<$selector> with
the content rendered by Template's I<PROCESS> directive applied to
C<$template>. C<%locals> are passed as local parameters to I<PROCESS>.

Uses jQuery's C<obj.replaceWith()> function. Requires jQuery to be loaded.

Example:

  <div>TODO:</div>
  <ul>
    <li id="item1">First item</li>
    <li id="item2">Second item</li>
    <li id="item3">Another item</li>
  </ul>

  <script type="text/javascript">
    function do_work() {
      [% JavaScript.replace_with('#item2', 'todo/single_item', item => current_todo_item) %]
    }
  </script>

  <input type="submit" onclick="do_work(); return false;" value="Replace single item">

=item C<replace_html_with $selector, $template, %locals>

Returns code replacing the inner HTML of the DOM elements matched by
C<$selector> with the content rendered by Template's I<PROCESS>
directive applied to C<$template>. C<%locals> are passed as local
parameters to I<PROCESS>.

Uses jQuery's C<obj.html()> function. Requires jQuery to be loaded.

  <div>TODO:</div>
  <ul id="todo_list">
    <li id="item1">First item</li>
    <li id="item2">Second item</li>
    <li id="item3">Another item</li>
  </ul>

  <script type="text/javascript">
    function do_work() {
      [% JavaScript.replace_html_with('#todo_list', 'todo/full_list', items => todo_items) %]
    }
  </script>

  <input type="submit" onclick="do_work(); return false;" value="Replace list">

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
