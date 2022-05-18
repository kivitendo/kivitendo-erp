package SL::BackgroundJob::CreateOrUpdateFileFullTexts;

use strict;

use parent qw(SL::BackgroundJob::Base);

use Encode qw(decode);
use English qw( -no_match_vars );
use File::Slurp qw(read_file);
use List::MoreUtils qw(uniq);
use IPC::Run qw();
use Unicode::Normalize qw();

use SL::DB::File;
use SL::DB::FileFullText;
use SL::HTML::Util;

my %extractor_by_mime_type = (
  'application/pdf' => \&_pdf_to_strings,
  'text/html'       => \&_html_to_strings,
  'text/plain'      => \&_text_to_strings,
);

sub create_job {
  $_[0]->create_standard_job('20 3 * * *'); # # every day at 3:20 am
}

#
# If job does not throw an error,
# success in background_job_histories is 'success'.
# It is 'failure' otherwise.
#
# return value goes to result in background_job_histories
#
sub run {
  my $self    = shift;
  my $db_obj  = shift;

  my $all_dbfiles = SL::DB::Manager::File->get_all;

  foreach my $dbfile (@$all_dbfiles) {
    next if $dbfile->full_text && (($dbfile->mtime || $dbfile->itime) <= ($dbfile->full_text->mtime || $dbfile->full_text->itime));
    next if !defined $extractor_by_mime_type{$dbfile->mime_type};

    my $file_name;
    if (!eval { $file_name = SL::File->get(dbfile => $dbfile)->get_file(); 1; }) {
      $::lxdebug->message(LXDebug::WARN(), "CreateOrUpdateFileFullTexts::run: get_file failed: " . $EVAL_ERROR);
      next;
    }

    my $text = $extractor_by_mime_type{$dbfile->mime_type}->($file_name);

    if ($dbfile->full_text) {
      $dbfile->full_text->update_attributes(full_text => $text);
    } else {
      SL::DB::FileFullText->new(file => $dbfile, full_text => $text)->save;
    }
  }

  return 'ok';
}

sub _pdf_to_strings {
  my ($file_name) = @_;

  my   @cmd = qw(pdftotext -enc UTF-8);
  push @cmd,  $file_name;
  push @cmd,  '-';

  my ($txt, $err);

  IPC::Run::run \@cmd, \undef, \$txt, \$err;

  if ($CHILD_ERROR) {
    $::lxdebug->message(LXDebug::WARN(), "CreateOrUpdateFileFullTexts::_pdf_to_text failed for '$file_name': " . ($CHILD_ERROR >> 8) . ": " . $err);
    return '';
  }

  $txt = Encode::decode('utf-8-strict', $txt);
  $txt =~ s{\r}{ }g;
  $txt =~ s{\p{WSpace}+}{ }g;
  $txt = Unicode::Normalize::normalize('C', $txt);
  $txt = join ' ' , uniq(split(' ', $txt));

  return $txt;
}

sub _html_to_strings {
  my ($file_name) = @_;

  my $txt = read_file($file_name);

  $txt = Encode::decode('utf-8-strict', $txt);
  $txt = SL::HTML::Util::strip($txt);
  $txt =~ s{\r}{ }g;
  $txt =~ s{\p{WSpace}+}{ }g;
  $txt = Unicode::Normalize::normalize('C', $txt);
  $txt = join ' ' , uniq(split(' ', $txt));

  return $txt;
}

sub _text_to_strings {
  my ($file_name) = @_;

  my $txt = read_file($file_name);

  $txt = Encode::decode('utf-8-strict', $txt);
  $txt =~ s{\r}{ }g;
  $txt =~ s{\p{WSpace}+}{ }g;
  $txt = Unicode::Normalize::normalize('C', $txt);
  $txt = join ' ' , uniq(split(' ', $txt));

  return $txt;
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::BackgroundJob::CreateOrUpdateFileFullTexts - Extract text strings/words from
files in the DMS for full text search.

=head1 SYNOPSIS

Search all documents in the files table and try to extract strings from them
and store the strings in the database.

Duplicate strings/words in one text are removed.

Strings are updated if the change or creation time of the document is newer than
the old entry.

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
