package SL::Webdav;

use strict;
use parent qw(Rose::Object);

use Encode qw(decode);
use File::Spec;
use SL::Common;
use SL::Webdav::File;
use SL::Webdav::Object;
use SL::Webdav::VersionScheme::Serial;
use SL::Webdav::VersionScheme::Timestamp;

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(type number) ],
  'scalar --get_set_init' => [ qw(version_scheme) ],
);

my %type_to_path = (
  sales_quotation         => 'angebote',
  sales_order             => 'bestellungen',
  request_quotation       => 'anfragen',
  purchase_order          => 'lieferantenbestellungen',
  sales_delivery_order    => 'verkaufslieferscheine',
  purchase_delivery_order => 'einkaufslieferscheine',
  credit_note             => 'gutschriften',
  invoice                 => 'rechnungen',
  purchase_invoice        => 'einkaufsrechnungen',
  part                    => 'waren',
  service                 => 'dienstleistungen',
  assembly                => 'erzeugnisse',
  letter                  => 'briefe',
  general_ledger          => 'dialogbuchungen',
  accounts_payable        => 'kreditorenbuchungen',
  customer                => 'kunden',
  vendor                  => 'lieferanten',
);

sub get_all_files {
  my ($self) = @_;

  my @objects = $self->get_all_objects;
  my %files_by_name;

  for my $obj (@objects) {
    my $filename = join '.', grep $_, $obj->basename, $obj->extension;

    my $file = $files_by_name{$filename} ||= SL::Webdav::File->new(filename => $filename, webdav => $self, loaded => 1);
    $file->add_objects($obj);
  }

  return values %files_by_name;
}

sub get_all_objects {
  my ($self) = @_;

  my $path = $self->webdav_path;
  my @objects;

  my $base_path = $ENV{'SCRIPT_NAME'};
  $base_path =~ s|[^/]+$||;
  if (opendir my $dir, $path) {
    foreach my $file (sort { lc $a cmp lc $b } map { decode("UTF-8", $_) } readdir $dir) {
      next if (($file eq '.') || ($file eq '..'));

      my $fname = $file;
      $fname  =~ s|.*/||;

      push @objects, SL::Webdav::Object->new(filename => $fname, webdav => $self);
    }

    closedir $dir;

    return @objects;
  }
}

sub get_all_latest {
  my ($self) = @_;

  my @files = $self->get_all_files;
  map { ($_->versions)[-1] } @files;
}

sub _sanitized_number {
  my $number = $_[0]->number;
  $number =~ s|[/\\]|_|g;
  $number;
}

sub webdav_path {
  my ($self) = @_;

  die "No client set in \$::auth" unless $::auth->client;
  die "Need number"               unless $self->number;

  my $type = $type_to_path{$self->type};

  die "Unknown type"              unless $type;

  my $path = File::Spec->catdir("webdav", $::auth->client->{id}, $type, $self->_sanitized_number);

  if (!-d $path) {
    Common::mkdir_with_parents($path);
  }

  return $path;
}

sub init_version_scheme {
  SL::Webdav::VersionScheme::Timestamp->new;
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Webdav - Webdav manipulation

=head1 SYNOPSIS

  # get list of all documents for this record
  use SL::Webdav;

  my $webdav = SL::Webdav->new(
    type     => 'part',
    number   => $number,
  );

  # gives you SL::Webdav::File instances
  my $webdav_files = $webdav->get_all_files;

  # gives you the objects instead
  my $webdav_objects = $webdav->get_all_objects;

  # gives you only the latest objects
  my $webdav_objects = $webdav->get_all_latest;

  # physical path to this dir
  my $path = $webdav->webdav_path;

=head1 DESCRIPTION

This module is a wrapper around the webdav storage mechanism with some simple
document management functionality.

This is not a replacement for real document management, mostly because the
underlying webdav storage is not fully under our control. It's common practice
to allow people direct samba access to the webdav, so all versioning
information needs to be encoded into the filename of a file, and nonsensical
filenames must not break assumptions.

This module is intended to be used if you need to scan the folder for
previously saved files and need to build a list in order to display it.

If you need to manipulate the versions of a file, see L<SL::Webdav::File>

If you need to access a file directly for download or metadata, see L<SL::Webdav::Object>

=head1 FUNCTIONS

=over 4

=item C<get_all_objects>

Returns all L<SL::Webdav::Objects> found.

=item C<get_all_files>

Returns all objects sorted into L<SL::Webdav::File>s.

=item C<get_all_latest>

Returns only the latest object of each L<SL::Webdav::File> found.

=item C<webdav_path>

Returns the physical path to this webdav object.

=back

=head1 VERSIONING SCHEME

You may register a versioning scheme object to handle versioning. It is
expected to implement the following methods:

=over 4

=item C<separator>

Must return a string that will be used to separate the basename and version part of
filenames when generating and parsing.

=item C<extract_regexp>

Must return a regexp that will match a versioning string at the end of a
filename after the extension has been stripped off. It will be surrounded by
captures.

=item C<cmp>

Must return a comparison function that will be invoked with two
L<SL::Webdav::Object> instances.

=item C<first_version>

Must return a string representing the version of the first of a series of objects.

May return undef.

=item C<next_version>

Will be called with the latest L<SL::Webdav::Object> and must return a new version string.

=item C<keep_last_version>

Will be called with the latest L<SL::Webdav::Object>. Truish return value will
cause the latest object to be overwritten instead of creating a new version.

=back

=head1 BUGS AND CAVEATS

=over 4

=item *

File operations are inconsistently L<File::Spec>ed.

=back

=head1 SEE ALSO

L<SL::Webdav::File>, L<SL::Webdav::Object>

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
