package SL::Template::Plugin::KiviLatex;

use strict;
use parent qw( Template::Plugin::Filter );

my $cached_instance;

sub new {
  my $class = shift;

  return $cached_instance ||= $class->SUPER::new(@_);
}

sub init {
  my $self = shift;

  $self->install_filter($self->{ _ARGS }->[0] || 'KiviLatex');

  return $self;
}

sub filter {
  my ($self, $text, $args) = @_;
  return $::locale->quote_special_chars('Template/LaTeX', $text);
}

my %html_replace = (
  '</p>'      => "\n\n",
  '<ul>'      => "\\begin{compactitem} ",
  '</ul>'     => "\\end{compactitem} ",
  '<ol>'      => "\\begin{enumerate} ",
  '</ol>'     => "\\end{enumerate} ",
  '<li>'      => "\\item ",
  '</li>'     => " ",
  '<b>'       => "\\textbf{",
  '</b>'      => "}",
  '<strong>'  => "\\textbf{",
  '</strong>' => "}",
  '<i>'       => "\\textit{",
  '</i>'      => "}",
  '<em>'      => "\\textit{",
  '</em>'     => "}",
  '<u>'       => "\\uline{",
  '</u>'      => "}",
  '<s>'       => "\\sout{",
  '</s>'      => "}",
  '<sub>'     => "\\textsubscript{",
  '</sub>'    => "}",
  '<sup>'     => "\\textsuperscript{",
  '</sup>'    => "}",
  '<br/>'     => "\\newline ",
  '<br>'      => "\\newline ",
);

sub filter_html {
  my ($self, $text, $args) = @_;

  $text =~ s{ \r+ }{}gx;
  $text =~ s{ \n+ }{ }gx;
  $text =~ s{ (?:\&nbsp;|\s)+ }{ }gx;
  $text =~ s{ <ul>\s*</ul> | <ol>\s*</ol> }{}gx; # Remove lists without items. Can happen with copy & paste from e.g. LibreOffice.

  my @parts = map {
    if (substr($_, 0, 1) eq '<') {
      s{ +}{}g;
      $html_replace{$_} || '';

    } else {
      $::locale->quote_special_chars('Template/LaTeX', HTML::Entities::decode_entities($_));
    }
  } split(m{(<.*?>)}x, $text);

  return join('', @parts);
}

sub required_packages_for_html {
  my ($self) = @_;

  return <<EOLATEX;
\\usepackage{ulem}
EOLATEX
}

return 'SL::Template::Plugin::KiviLatex';
__END__

=pod

=encoding utf8

=head1 NAME

SL::Template::Plugin::KiviLatex - Template::Toolkit plugin for
escaping text for use in LaTeX templates

=head1 SYNOPSIS

From within a LaTeX template. Activate both Template::Toolkit in
general and this plugin in particular; must be located before
C<\begin{document}>:

  % config: use-template-toolkit=1
  % config: tag-style=$( )$
  $( USE KiviLatex )$

Later escape some text:

  $( KiviLatex.format(longdescription) )$

=head1 FUNCTIONS

=over 4

=item C<filter $text>

Escapes characters in C<$text> with the appropriate LaTeX
constructs. Expects normal text without any markup (no HTML, no XML
etc). Returns the whole escaped text.

=item C<filter_html $html>

Converts HTML markup in C<$html> to the appropriate LaTeX
constructs. Only the following HTML elements are supported:

=over 2

=item * C<b>, C<strong> – bold text

=item * C<it>, C<em> – italic text

=item * C<ul> – underlined text

=item * C<s> – striked out text

=item * C<sub>, C<sup> – subscripted and superscripted text

=item * C<ul>, C<ol>, C<li> – unordered lists (converted to an itemized
list), ordered lists (converted to enumerated lists) and their list
items

=item * C<p>, C<br> – Paragraph markers and line breaks

=back

This function is tailored for working on the input of CKEditor, not on
arbitrary HTML content. It works nicely in tandem with the
Rose::DB::Object helper functions C<…_as_restricted_html> (see
L<SL::DB::Helper::AttrHTML/attr_html>).

Attributes are silently removed and ignored. All other markup and the
normal text are escaped the same as in L</filter>.

=item C<init>

=item C<new>

Initializes the plugin. Automatically called by Template::Toolkit when
the plugin is loaded.

=item C<required_packages_for_html>

Returns LaTeX code loading packages that are required for the
formatting done with L</filter_html>. This function must be called and
its output inserted before the C<\begin{document}> line if that
function is used within the document.

It is not required for normal text escaping with L</filter>.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
