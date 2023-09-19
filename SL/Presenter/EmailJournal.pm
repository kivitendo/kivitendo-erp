package SL::Presenter::EmailJournal;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag         qw(link_tag img_tag html_tag);
use SL::Locale::String qw(t8);
use SL::SessionFile::Random;

use Exporter qw(import);
our @EXPORT_OK = qw(email_journal entry_status attachment_preview);

use Carp;

sub email_journal {
  my ($email_journal_entry, %params) = @_;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $text = escape($email_journal_entry->subject);
  if (! delete $params{no_link}) {
    my $href = 'controller.pl?action=EmailJournal/show'
               . '&id=' . escape($email_journal_entry->id);
    $text = link_tag($href, $text, %params);
  }

  is_escaped($text);
}

sub entry_status {
  my ($email_journal_entry, %params) = @_;

  my %status_to_text = (
    sent        => t8('sent'),
    send_failed => t8('send failed'),
    imported    => t8('imported'),
  );

  my $status = $email_journal_entry->status;
  my $text   = $status_to_text{$status} || $status;

  return $text;
}

sub attachment_preview {
  my ($attachment, %params) = @_;

  if (! $attachment) {
    return is_escaped(html_tag('div', '', id => 'attachment_preview'));
  }

  # clean up mime_type
  my $mime_type = $attachment->mime_type;
  $mime_type =~ s/;.*//;

  # parse to img tag
  my $image_tags = '';
  if ($mime_type =~ m{^image/}) {
    my $image_content = $attachment->content;
    my $img_base64 = "data:$mime_type;base64," . MIME::Base64::encode_base64($image_content);
    my $image_tag = img_tag(
      src => $img_base64,
      alt => escape($attachment->name),
      %params);
    $image_tags .= $image_tag;
  } elsif ($mime_type =~ m{^application/pdf}) {
    my $pdf_content = $attachment->content;
    my $session_file = SL::SessionFile::Random->new(mode => 'w');
    $session_file->fh->print($pdf_content);
    $session_file->fh->close;
    my $image_size = 2048;

    my $file_name = $session_file->file_name;

    # files are created in session_files folder
    my $command = 'pdftoppm -forcenum -scale-to '
                  . $image_size . ' -png' . ' '
                  . $file_name . ' ' . $file_name;
    my $ans = system($command);
    if ($ans != 0) {
      return;
    }


    my @image_file_names = glob($file_name . '-*.png');
    unlink($file_name);

    my $image_count = scalar @image_file_names;
    my $counter = 1;
    foreach my $image_file_name (@image_file_names) {
      my $image_file = SL::SessionFile->new($image_file_name, mode => 'r');
      my $file_size = -s $image_file->file_name;
      my $image_content;
      read($image_file->fh, $image_content, $file_size);
      my $img_base64 = 'data:image/png;base64,' . MIME::Base64::encode_base64($image_content);
      my $name_ending = $image_count > 1 ? "-($counter/$image_count)" : '';
      my $image_tag = img_tag(
        src => $img_base64,
        alt => escape($attachment->name) . $name_ending,
        %params);
      unlink($image_file->file_name);
      $image_tags .= $image_tag;
    }
  }

  my $attachment_preview = html_tag('div', $image_tags, id => 'attachment_preview');

  return is_escaped($attachment_preview);
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::EmailJournal - Presenter module for mail entries in email_journal

=head1 SYNOPSIS

  use SL::Presenter::EmailJournal;

  my $journal_entry = SL::DB::Manager::EmailJournal->get_first();
  my $html   = SL::Presenter::EmailJournal::email_journal($journal_entry, display => 'inline');

  # pp $html
  # <a href="controller.pl?action=EmailJournal/show&amp;id=1">IDEV Daten fuer webdav/idev/2017-KW-26.csv erzeugt</a>

=head1 FUNCTIONS

=over 4

=item C<email_journal $object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the email journal object C<$object>
.

Remaining C<%params> are passed to the function
C<SL::Presenter::Tag::link_tag>. It can include:

=over 2

=item * display

Either C<inline> (the default) or C<table-cell>. Is passed to the function C<SL::Presenter::Tag::link_tag>.

=item * no_link

If falsish (the default) then the mail subject will be linked to the
'view details of email' dialog from the email journal report.

=back

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

copied from Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>
by Jan Büren E<lt>jan@kivitendo-premium.deE<gt>

=cut
