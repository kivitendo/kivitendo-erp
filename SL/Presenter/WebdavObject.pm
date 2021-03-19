package SL::Presenter::WebdavObject;

use strict;

use SL::Presenter::Tag         qw(link_tag);
use SL::Presenter::EscapedText qw(escape is_escaped);

use Exporter qw(import);
our @EXPORT_OK = qw(webdav_object);

use Carp;

sub webdav_object {
  my ($webdav_object, %params) = @_;


  my $text = escape($webdav_object->filename);
  if (! delete $params{no_link}) {
    my $href  = SL::Presenter::EscapedText::escape($webdav_object->full_filedescriptor);
    $text     = link_tag($href, $text, %params);
  }

  is_escaped($text);
}

1;


__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::WebdavObject - Presenter module for SL::Webdav::Object(s).

=head1 SYNOPSIS

  my $webdav = SL::Webdav->new(
    type     => 'sales_order',
    number   => '1234',
  );
  my @all_objects = $webdav->get_all_objects;
  my $html        = SL::Presenter::WebdavObject::webdav_object($all_objects[0], no_link => 1);

=head1 FUNCTIONS

=over 4

=item C<webdav_object $webdav_object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the webdav object
C<$webdav_object>.

C<%params> can include:

=over 2

=item * no_link

If falsish (the default) then the file name of the object will be linked
to the download path for that file.

=back

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
