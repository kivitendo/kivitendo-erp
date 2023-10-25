package SL::Presenter::Dunning;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag         qw(link_tag);

use Exporter qw(import);
our @EXPORT_OK = qw(show dunning);

use Carp;

sub show {goto &dunning};

sub dunning {
  my ($dunning, %params) = @_;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $text = escape($dunning->dunning_config->dunning_description);
  if (! delete $params{no_link}) {
    my @flags = ();
    push @flags, 'showold=1';
    push @flags, 'l_mails=1'      if $::instance_conf->get_email_journal;
    push @flags, 'l_webdav=1'     if $::instance_conf->get_webdav;
    push @flags, 'l_documents=1'  if $::instance_conf->get_doc_storage;

    my $href  = 'dn.pl?action=show_dunning&dunning_id=' . $dunning->dunning_id;
    $href    .= '&' . join '&', @flags if @flags;
    $text     = link_tag($href, $text, %params);
  }

  is_escaped($text);
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::Dunning - Presenter module for SL::DB::Dunning objects

=head1 SYNOPSIS

  my $object = SL::DB::Manager::Dunning->get_first();
  my $html   = SL::Presenter::Dunning::dunning($object);
  # or
  my $html   = $object->presenter->show();

=head1 FUNCTIONS

=over 4

=item C<show $object>

Alias for C<dunning $object %params>.

=item C<dunning $object %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the dunning object
C<$object>.

Remaining C<%params> are passed to the function
C<SL::Presenter::Tag::link_tag>. It can include:

=over 2

=item * no_link

If falsish (the default) then the  dunning will be linked to the "show" dialog.

=back

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Tamino Steinert E<lt>tamino.steinert@tamino.stE<gt>

=cut
