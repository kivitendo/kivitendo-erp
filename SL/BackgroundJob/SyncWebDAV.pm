package SL::BackgroundJob::SyncWebDAV;

use strict;
use warnings;

use parent qw(SL::BackgroundJob::Base);

use SL::DB::BackgroundJobHistory;
use HTTP::DAV;
use File::Find;
use Cwd;
use Data::Dumper;

sub create_job {
  $_[0]->create_standard_job('0 3 * * *'); # daily at 3:00 am
}

sub run {
  my $self    = shift;
  my $db_obj  = shift;

  my $options     = $db_obj->data_as_hash;
  my $DELETE_ONLY = 0 || $options->{delete};

  return unless $::instance_conf->get_webdav_sync_extern;

  my $ret;

  my $dav     = HTTP::DAV->new();
  my $url     = $::instance_conf->get_webdav_sync_extern_url;
  $url        =~ s|/\z||;  # no trailing slashes

  $dav->credentials(
       -user  =>  $::instance_conf->get_webdav_sync_extern_login,
       -pass  =>  $::instance_conf->get_webdav_sync_extern_pass,
       -url   =>  $url,
  );
  my $client_id   = $options->{client_id} || $::auth->get_session_value('client_id');
  my $cwd = getcwd();

  my @fails;

  eval {

    my (@webdav_dir_temp, @webdav_dir, @webdav_files);

    # chdir to client root
    my $webdav = $cwd. "/webdav/$client_id/";
    chdir($webdav) or die "couldn't change into webdav dir"; # TODO throw better error message (Permission denied, etc)

    find( { wanted => sub { push @webdav_dir_temp, -d && $_}, no_chdir => 1 }, '.');
    find( { wanted => sub { push @webdav_files, -f && $_}, no_chdir => 1    }, '.');

    shift @webdav_dir_temp; # first element would be undef after substr
    foreach (@webdav_dir_temp) {
      next unless $_;
      push @webdav_dir, substr($_,2);
    }
    @webdav_files = map { substr($_,2) } grep { $_ =~ m/.*pdf/ } @webdav_files;

    $ret = $dav->open(-url => $url) or die "Can't open url $url";
    # Make a null lock on repo for 5minutes
    #$ret = $dav->lock(-url => $url, -timeout => "30m") or die;

    foreach (@webdav_dir) {
      last if $DELETE_ONLY;

      $ret             = $dav->options(-url => $url . '/' . $_);
      next unless $ret =~ m/MKCOL/;

      unless ( $dav->mkcol($_) ) {
        push(@fails, "Cannot make dir $_");
      };
    }

    #$dav->unlock(-url => $url); # UNLOCK after DIR sync
    # now we have all dirs in sync, therefore we can place files
    foreach (@webdav_files) {
      last if $DELETE_ONLY;

      $ret         = $dav->options(-url => $url . '/' . $_);
      # $main::lxdebug->message(0, 'verzeichnis:'. $_ . '::' . $ret . ':' . $dav->message);
      next unless $ret =~ m/MKCOL/;  # file not there #owncloud gives DELETE even if file not there
      #$dav->lock(-url => $url . '/' . $_); # UNLOCK after DIR sync

      # $main::lxdebug->message(0, 'datei:'. $_);
      unless ( $dav->put(-local => $_, -url => $url . '/' . $_) ) {
        push(@fails, "Cannot put file $_");
      };
      #$dav->unlock(-url => $url . '/' . $_); # UNLOCK after put
    }

    # maybe we delete some stuff
    # TODO delete stuff here
    if ($DELETE_ONLY) {
      foreach (qw(anfragen bestellungen einkaufslieferscheine einkaufsrechnungen angebote
             gutschriften lieferantenbestellungen rechnungen verkaufslieferscheine)) {
        $ret = $dav->delete($url . "/$_");
      }

      # better, but not implemented - delete only local deleted stuff
      # idea: propfind all the above dirs and check if child (rel_uri) exists locally
      # if not, we can safely delete remote
      # if (my $r=$dav->propfind( -url=>"$_/", -depth=>1) ) { ...
    }

    #$dav->unlock(-url => $url);
    chdir($cwd);

    1;

  } or do {
    my $error = "dav: " . $dav->message . ", eval: " . $! . ", eval 2: " . $@;
   # $dav->unlock(-url => $url);    # unlock, just in case
    # chdir($cwd);
    die("Couldn't sync with external webdav repo at $url error code/protocol return:" . $error);
  };

  if ( @fails ) {
    die join("\n", @fails);
  };

  return 1;
}

1;

__END__

=encoding utf8

=head1 NAME

SL::BackgroundJob::ExternalSyncWebDAV - Background job for
syncing all folders and files for current client to a external
webdav-repository

=head1 SYNOPSIS

This background job copies all files and folders for one client
to a external webdav-repo.
A optional param C<delete> can be set to 1 to delete (clean)
the external repo. If set to undef or 0 a folderwise copy will be
executed.
To test with different clients a param C<client_id> will overload
the current client id.
The settings for the external repo are in client config.
If a lock still exists, the job returns a Internal Server Error
from the webdav server.
Only pdf files are considered valid files to copy.

The job is supposed to run once a day.

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Jan Büren E<lt>jan@kivitendo-premium.deE<gt>

=cut

