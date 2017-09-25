package SL::File::Backend::Webdav;

use strict;

use parent qw(SL::File::Backend);
use SL::DB::File;

#use SL::Webdav;
use File::Copy;
use File::Slurp;
use File::Basename;
use File::Path qw(make_path);
use File::MimeInfo::Magic;

#
# public methods
#

sub delete {
  my ($self, %params) = @_;
  $main::lxdebug->message(LXDebug->DEBUG2(), "del in backend " . $self . "  file " . $params{dbfile});
  $main::lxdebug->message(LXDebug->DEBUG2(), "file id=" . $params{dbfile}->id * 1);
  return 0 unless $params{dbfile};
  my ($file_path, undef, undef) = $self->webdav_path($params{dbfile});
  unlink($file_path);
  return 1;
}

sub rename {
  my ($self, %params) = @_;
  return 0 unless $params{dbfile};
  my (undef, $oldwebdavname) = split(/:/, $params{dbfile}->location, 2);
  my ($tofile, $basepath, $basename) = $self->webdav_path($params{dbfile});
  my $fromfile = File::Spec->catfile($basepath, $oldwebdavname);
  $main::lxdebug->message(LXDebug->DEBUG2(), "renamefrom=" . $fromfile . " to=" . $tofile);
  move($fromfile, $tofile);
}

sub save {
  my ($self, %params) = @_;
  die 'dbfile not exists' unless $params{dbfile};
  $main::lxdebug->message(LXDebug->DEBUG2(), "in backend " . $self . "  file " . $params{dbfile});
  $main::lxdebug->message(LXDebug->DEBUG2(), "file id=" . $params{dbfile}->id);
  my $dbfile = $params{dbfile};
  die 'no file contents' unless $params{file_path} || $params{file_contents};

  if ($params{dbfile}->id * 1 == 0) {

    # new element: need id for file
    $params{dbfile}->save;
  }
  my ($tofile, undef, $basename) = $self->webdav_path($params{dbfile});
  if ($params{file_path} && -f $params{file_path}) {
    copy($params{file_path}, $tofile);
  }
  elsif ($params{file_contents}) {
    open(OUT, "> " . $tofile);
    print OUT $params{file_contents};
    close(OUT);
  }
  return 1;
}

sub get_version_count {
  my ($self, %params) = @_;
  die "no dbfile" unless $params{dbfile};
  ## TODO
  return 1;
}

sub get_mtime {
  my ($self, %params) = @_;
  die "no dbfile" unless $params{dbfile};
  $main::lxdebug->message(LXDebug->DEBUG2(), "version=" .$params{version});
  my ($path, undef, undef) = $self->webdav_path($params{dbfile});
  die "no file found in backend" if !-f $path;
  my @st = stat($path);
  my $dt = DateTime->from_epoch(epoch => $st[9])->clone();
  $main::lxdebug->message(LXDebug->DEBUG2(), "dt=" .$dt);
  return $dt;
}

sub get_filepath {
  my ($self, %params) = @_;
  die "no dbfile" unless $params{dbfile};
  my ($path, undef, undef) = $self->webdav_path($params{dbfile});
  die "no file" if !-f $path;
  return $path;
}

sub get_content {
  my ($self, %params) = @_;
  my $path = $self->get_filepath(%params);
  return "" unless $path;
  my $contents = File::Slurp::read_file($path);
  return \$contents;
}

sub sync_from_backend {
  my ($self, %params) = @_;
  return unless $params{file_type};

  $self->sync_all_locations(%params);

}

sub enabled {
  return 0 unless $::instance_conf->get_doc_webdav;
  return 1;
}

#
# internals
#

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
  gl_transaction          => 'dialogbuchungen',
  accounts_payable        => 'kreditorenbuchungen',
  shop_image              => 'shopbilder',
);

my %type_to_model = (
  sales_quotation         => 'Order',
  sales_order             => 'Order',
  request_quotation       => 'Order',
  purchase_order          => 'Order',
  sales_delivery_order    => 'DeliveryOrder',
  purchase_delivery_order => 'DeliveryOrder',
  credit_note             => 'Invoice',
  invoice                 => 'Invoice',
  purchase_invoice        => 'PurchaseInvoice',
  part                    => 'Part',
  service                 => 'Part',
  assembly                => 'Part',
  letter                  => 'Letter',
  general_ledger          => 'GLTransaction',
  gl_transaction          => 'GLTransaction',
  accounts_payable        => 'GLTransaction',
  shop_image              => 'Part',
);

my %model_to_number = (
  Order           => 'ordnumber',
  DeliveryOrder   => 'ordnumber',
  Invoice         => 'invnumber',
  PurchaseInvoice => 'invnumber',
  Part            => 'partnumber',
  Letter          => 'letternumber',
  GLTransaction   => 'reference',
  ShopImage       => 'partnumber',
);

sub webdav_path {
  my ($self, $dbfile) = @_;

  #die "No webdav backend enabled" unless $::instance_conf->get_webdav;

  my $type = $type_to_path{ $dbfile->object_type };

  die "Unknown type" unless $type;

  my $number = $dbfile->backend_data;
  if ($number eq '') {
    $number = $self->_get_number_from_model($dbfile);
    $dbfile->backend_data($number);
    $dbfile->save;
  }
  $main::lxdebug->message(LXDebug->DEBUG2(), "file_name=" . $dbfile->file_name ." number=".$number);

  my @fileparts = split(/_/, $dbfile->file_name);
  my $number_ext = pop @fileparts;
  my ($maynumber, $ext) = split(/\./, $number_ext, 2);
  push @fileparts, $maynumber if $maynumber ne $number;

  my $basename = join('_', @fileparts);

  my $path = File::Spec->catdir($self->get_rootdir, "webdav", $::auth->client->{id}, $type, $number);
  if (!-d $path) {
    File::Path::make_path($path, { chmod => 0770 });
  }
  my $fname = $basename . '_' . $number . '_' . $dbfile->itime->strftime('%Y%m%d_%H%M%S');
  $fname .= '.' . $ext if $ext;

  $main::lxdebug->message(LXDebug->DEBUG2(), "webdav path=" . $path . " filename=" . $fname);

  return (File::Spec->catfile($path, $fname), $path, $fname);
}

sub get_rootdir {
  my ($self) = @_;

  #TODO immer noch das alte Problem:
  #je nachdem von woher der Aufruf kommt ist man in ./users oder .
  my $rootdir  = POSIX::getcwd();
  my $basename = basename($rootdir);
  my $dirname  = dirname($rootdir);
  $rootdir = $dirname if $basename eq 'users';
  return $rootdir;
}

sub _get_number_from_model {
  my ($self, $dbfile) = @_;

  my $class = 'SL::DB::' . $type_to_model{ $dbfile->object_type };
  eval "require $class";
  my $obj = $class->new(id => $dbfile->object_id)->load;
  die 'no object found' unless $obj;
  my $numberattr = $model_to_number{ $type_to_model{ $dbfile->object_type } };
  return $obj->$numberattr;
}

#
# TODO not fully imlemented and tested
#
sub sync_all_locations {
  my ($self, %params) = @_;

  my %dateparms = (dateformat => 'yyyymmdd');

  foreach my $type (keys %type_to_path) {

    my @query = (
      file_type => $params{file_type},
      object_type    => $type
    );
    my @oldfiles = @{ SL::DB::Manager::File->get_all(
        query => [
          file_type => $params{file_type},
          object_type    => $type
        ]
      )
    };

    my $path = File::Spec->catdir($self->get_rootdir, "webdav", $::auth->client->{id},$type_to_path{$type});

    if (opendir my $dir, $path) {
      foreach my $file (sort { lc $a cmp lc $b }
        map { decode("UTF-8", $_) } readdir $dir)
      {
        next if (($file eq '.') || ($file eq '..'));

        my $fname = $file;
        $fname =~ s|.*/||;

        my ($filename, $number, $date, $time_ext) = split(/_/, $fname);
        my ($time, $ext) = split(/\./, $time_ext, 2);

        $time = substr($time, 0, 2) . ':' . substr($time, 2, 2) . ':' . substr($time, 4, 2);

        #my @found = grep { $_->backend_data eq $fname } @oldfiles;
        #if (scalar(@found) > 0) {
        #  @oldfiles = grep { $_ != @found[0] } @oldfiles;
        #}
        #else {
          my $dbfile = SL::DB::File->new();
          my $class  = 'SL::DB::Manager::' . $type_to_model{$type};
          my $obj =
            $class->find_by(
            $model_to_number{ $type_to_model{$type} } => $number);
          if ($obj) {

            my $mime_type = File::MimeInfo::Magic::magic(File::Spec->catfile($path, $fname));
            if (!$mime_type) {
              # if filename has the suffix "pdf", but is really no pdf set mimetype for no suffix
              $mime_type = File::MimeInfo::Magic::mimetype($fname);
              $mime_type = 'application/octet-stream' if $mime_type eq 'application/pdf' || !$mime_type;
            }

            $dbfile->assign_attributes(
              object_id   => $obj->id,
              object_type => $type,
              source      => $params{file_type} eq 'document' ? 'created' : 'uploaded',
              file_type   => $params{file_type},
              file_name   => $filename . '_' . $number . '_' . $ext,
              mime_type   => $mime_type,
              itime       => $::locale->parse_date_to_object($date . ' ' . $time, %dateparms),
            );
            $dbfile->save;
          }
        #}

        closedir $dir;
      }
    }
  }
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::File::Backend::Filesystem  - Filesystem class for file storage backend

=head1 SYNOPSIS

See the synopsis of L<SL::File::Backend>.

=head1 OVERVIEW

This specific storage backend use a Filesystem which is only accessed by this interface.
This is the big difference to the Webdav backend where the files can be accessed without the control of that backend.
This backend use the database id of the SL::DB::File object as filename. The filesystem has up to 1000 subdirectories
to store the files not to flat in the filesystem.


=head1 METHODS

See methods of L<SL::File::Backend>.

=head1 SEE ALSO

L<SL::File::Backend>

=head1 TODO

The synchronization must be tested and a periodical task is needed to synchronize in some time periods.

=head1 AUTHOR

Martin Helmling E<lt>martin.helmling@opendynamic.deE<gt>

=cut


