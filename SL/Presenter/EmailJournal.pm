package SL::Presenter::EmailJournal;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag         qw(link_tag);
use SL::Locale::String qw(t8);

use Exporter qw(import);
our @EXPORT_OK = qw(email_journal entry_status);

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
