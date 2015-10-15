package SL::Template::HTML;

use parent qw(SL::Template::LaTeX);

use strict;

sub new {
  my $type = shift;

  return $type->SUPER::new(@_);
}

sub format_string {
  my ($self, $variable) = @_;
  my $form = $self->{"form"};

  $variable = $main::locale->quote_special_chars('Template/HTML', $variable);

  # Allow some HTML markup to be converted into the output format's
  # corresponding markup code, e.g. bold or italic.
  my @markup_replace = ('b', 'i', 's', 'u', 'sub', 'sup');

  foreach my $key (@markup_replace) {
    $variable =~ s/\&lt;(\/?)${key}\&gt;/<$1${key}>/g;
  }

  return $variable;
}

sub get_mime_type() {
  my ($self) = @_;

  if ($self->{"form"}->{"format"} =~ /postscript/i) {
    return "application/postscript";
  } elsif ($self->{"form"}->{"format"} =~ /pdf/i) {
    return "application/pdf";
  } else {
    return "text/html";
  }
}

sub uses_temp_file {
  my ($self) = @_;

  if ($self->{"form"}->{"format"} =~ /postscript/i) {
    return 1;
  } elsif ($self->{"form"}->{"format"} =~ /pdf/i) {
    return 1;
  } else {
    return 0;
  }
}

sub convert_to_postscript {
  my ($self) = @_;
  my ($form, $userspath) = ($self->{"form"}, $self->{"userspath"});

  # Convert the HTML file to postscript

  if (!chdir("$userspath")) {
    $self->{"error"} = "chdir : $!";
    $self->cleanup();
    return 0;
  }

  $form->{"tmpfile"} =~ s/\Q$userspath\E\///g;
  my $psfile = $form->{"tmpfile"};
  $psfile =~ s/.html/.ps/;
  if ($psfile eq $form->{"tmpfile"}) {
    $psfile .= ".ps";
  }

  if (system($::lx_office_conf{applications}->{html2ps} . " -f html2ps-config < $form->{tmpfile} > $psfile") == -1) {
    die "system call to $::lx_office_conf{applications}->{html2ps} failed: $!";
  }
  if ($?) {
    $self->{"error"} = $form->cleanup($::lx_office_conf{applications}->{html2ps});
    return 0;
  }

  $form->{"tmpfile"} = $psfile;

  $self->cleanup();

  return 1;
}

sub convert_to_pdf {
  my ($self) = @_;
  my ($form, $userspath) = ($self->{"form"}, $self->{"userspath"});

  # Convert the HTML file to PDF

  if (!chdir("$userspath")) {
    $self->{"error"} = "chdir : $!";
    $self->cleanup();
    return 0;
  }

  $form->{"tmpfile"} =~ s/\Q$userspath\E\///g;
  my $pdffile = $form->{"tmpfile"};
  $pdffile =~ s/.html/.pdf/;
  if ($pdffile eq $form->{"tmpfile"}) {
    $pdffile .= ".pdf";
  }

  if (system($::lx_office_conf{applications}->{html2ps} . " -f html2ps-config < $form->{tmpfile} | ps2pdf - $pdffile") == -1) {
    die "system call to $::lx_office_conf{applications}->{html2ps} failed: $!";
  }
  if ($?) {
    $self->{"error"} = $form->cleanup($::lx_office_conf{applications}->{html2ps});
    return 0;
  }

  $form->{"tmpfile"} = $pdffile;

  $self->cleanup();

  return 1;
}

1;
