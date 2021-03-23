package SL::Presenter::Dunning;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag         qw(link_tag);

use Exporter qw(import);
our @EXPORT_OK = qw(dunning);

use Carp;

sub dunning {
  my ($dunning, %params) = @_;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $text = escape($dunning->dunning_config->dunning_description);

  if (! delete $params{no_link}) {
    my @flags;
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
