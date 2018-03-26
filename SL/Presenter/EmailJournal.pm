package SL::Presenter::EmailJournal;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);

use Exporter qw(import);
our @EXPORT_OK = qw(email_journal);

use Carp;

sub email_journal {
  my ($email_journal_entry, %params) = @_;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $text = join '', (
    $params{no_link} ? '' : '<a href="controller.pl?action=EmailJournal/show&amp;id=' . escape($email_journal_entry->id) . '">',
    escape($email_journal_entry->subject),
    $params{no_link} ? '' : '</a>',
  );

  is_escaped($text);
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


C<%params> can include:

=over 2

=item * display

Either C<inline> (the default) or C<table-cell>. At the moment both
representations are identical and produce the invoice number linked
to the corresponding 'edit' action.

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
