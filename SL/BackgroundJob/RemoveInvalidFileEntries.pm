package SL::BackgroundJob::RemoveInvalidFileEntries;

use strict;
use warnings;

use parent qw(SL::BackgroundJob::Base);

use SL::File;

use constant WAITING_FOR_EXECUTION => 0;
use constant SCAN_START            => 1;
use constant DONE                  => 2;

# Data format:
# my $data = {
#   file_errors = [
#     "Ich bin ein Fehler",
#   ],
# }

sub scan_file_entry {
  my ($self)  = @_;
  my $job_obj = $self->{job_obj};
  $job_obj->set_data(status => SCAN_START())->save;

  my @file_entries = @{ SL::DB::Manager::File->get_all() };

  my @files = map { SL::File::Object->new(db_file => $_, id => $_->id, loaded => 1) } @file_entries;

  my $data  = $job_obj->data_as_hash;
  foreach my $file (@files) {
    unless (eval {$file->get_file()}) {
      #warn $@;
      push(@{$data->{file_errors}}, $@);
      $job_obj->update_attributes(data_as_hash => $data);
      $file->loaded_db_file->delete();
    }
  }
}

sub run {
  my ($self, $job_obj) = @_;
  $self->{job_obj} = $job_obj;

  $self->scan_file_entry();

  $job_obj->set_data(status => DONE())->save;
  return 1;
}

1;
