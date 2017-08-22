use strict;
use Test::More tests => 14;

use lib 't';

use File::Temp;
use Support::TestSetup;
use Test::Exception;
use SL::File;
use SL::Dev::File qw(create_uploaded create_scanned create_created);


Support::TestSetup::login();

my $temp_dir    = File::Temp::tempdir("kivi-t-file-filesystem.XXXXXX", TMPDIR => 1, CLEANUP => 1);
my $storage_dir = "$temp_dir/storage";

mkdir($storage_dir) || die $!;
{
local $::lx_office_conf{paths}->{document_path} = $storage_dir;
$::instance_conf->data;
local $::instance_conf->{data}{doc_files} = 1;

my $scannerfile = "${temp_dir}/f2";

clear_up();
reset_state();

my $file1 = create_uploaded( file_name => 'file1', file_contents => 'inhalt1 uploaded' );
my $file2 = create_scanned(  file_name => 'file2', file_contents => 'inhalt2 scanned', file_path => $scannerfile );
my $file3 = create_created(  file_name => 'file3', file_contents => 'inhalt3 created'    );
my $file4 = create_created(  file_name => 'file3', file_contents => 'inhalt3 new version');

is( SL::Dev::File::get_all_count(),                    3,"total number of files created is 3");
ok( $file1->file_name                        eq 'file1' ,"file has right name");
my $content1 = $file1->get_content;
ok( $$content1 eq 'inhalt1 uploaded'                    ,"file has right content");

is( -f $scannerfile ? 1 : 0,                           0,"scanned document is moved from scanner");

$file2->delete;
is( -f $scannerfile ? 1 : 0,                           1,"scanned document is moved back to scanner");
my $content2 = File::Slurp::read_file($scannerfile);
ok( $content2 eq 'inhalt2 scanned'                      ,"scanned file has right content");

my @file5 = SL::Dev::File::get_all(file_name => 'file3');
is(   scalar( @file5),                                 1, "one actual file found");
my $content5 = $file5[0]->get_content();
ok( $$content5 eq 'inhalt3 new version'                 ,"file has right actual content");

my @file6 = SL::Dev::File::get_all_versions(file_name => 'file3');
is(   scalar( @file6),                                 2,"two file versions found");
$content5 = $file6[0]->get_content;
ok( $$content5 eq 'inhalt3 new version'                 ,"file has right actual content");
$content5 = $file6[1]->get_content;
ok( $$content5 eq 'inhalt3 created'                     ,"file has right old content");

#print "\n\nController Test:\n";
# now test controller
#$::form->{object_id}  = 1;
#$::form->{object_type}= 'sales_order';
#$::form->{file_type}  = 'document';

my $output;
open(my $outputFH, '>', \$output) or die; # This shouldn't fail
my $oldFH = select $outputFH;

$::form->{id}  = $file1->id;
use SL::Controller::File;
SL::Controller::File->action_download();

select $oldFH;
close $outputFH;
my @lines = split "\n" , $output;
ok($lines[4] eq 'inhalt1 uploaded'                 ,"controller download has correct content");

#some controller checks
$::form->{object_id}   = 12345678;
$::form->{object_type} = undef;
my $result='xx1';
eval {
  SL::Controller::File->check_object_params();
  $result='yy1';
  1;
} or do {
  $result=$@;
};
$result = substr($result,0,14);
#print $result."\n";
ok($result eq "No object type","correct error 'No object type'");

$::form->{object_type} ='sales_order';
$::form->{file_type} ='';
$result='xx2';
eval {
  SL::Controller::File->check_object_params();
  $result='yy2';
  1;
} or do {
  $result=$@;
};
$result = substr($result,0,12);
#print $result."\n";
ok($result eq "No file type","correct error 'No file type'");

clear_up();
done_testing;

sub clear_up {
  # Cleaning up may fail.
  eval {
    SL::Dev::File::delete_all();
    unlink($scannerfile);
  };
}

}

sub reset_state {
  my %params = @_;

};

1;
