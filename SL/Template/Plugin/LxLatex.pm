package SL::Template::Plugin::LxLatex;

use strict;
use parent qw( Template::Plugin::Filter );

my $cached_instance;

sub new {
  my $class = shift;

  return $cached_instance ||= $class->SUPER::new(@_);
}

sub init {
  my $self = shift;

  $self->install_filter($self->{ _ARGS }->[0] || 'LxLatex');

  return $self;
}

sub filter {
  my ($self, $text, $args) = @_;
  return $::locale->quote_special_chars('Template/LaTeX', $text);
}

my %html_replace = (
  '</p>'      => "\n\n",
  '<ul>'      => "\\begin{itemize} ",
  '</ul>'     => "\\end{itemize} ",
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
  '<u>'       => "\\underline{",
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

return 'SL::Template::Plugin::LxLatex';
