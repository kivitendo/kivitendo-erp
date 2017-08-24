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

my %common_params = (
  object_id   => 1,
  object_type => 'sales_order',
);

mkdir($storage_dir) || die $!;
{
local $::lx_office_conf{paths}->{document_path} = $storage_dir;
$::instance_conf->data;
local $::instance_conf->{data}{doc_files} = 1;

my $scanner_file = "${temp_dir}/f2";

clear_up();

note('testing SL::File');

my $file1 = create_uploaded( %common_params, file_name => 'file1', file_contents => 'content1 uploaded' );
my $file2 = create_scanned(  %common_params, file_name => 'file2', file_contents => 'content2 scanned', file_path => $scanner_file );
my $file3 = create_created(  %common_params, file_name => 'file3', file_contents => 'content3 created'    );
my $file4 = create_created(  %common_params, file_name => 'file3', file_contents => 'content3 new version');

is( SL::File->get_all_count(%common_params), 3, "3 files were created");
ok( $file1->file_name              eq 'file1' , "file1 has correct name");
my $content1 = $file1->get_content;
ok( $$content1 eq 'content1 uploaded'         , "file1 has correct content");

is( -f $scanner_file ? 1 : 0,                0, "scanned document was moved from scanner");

$file2->delete;
is( -f $scanner_file ? 1 : 0,                1, "scanned document was moved back to scanner");
my $content2 = File::Slurp::read_file($scanner_file);
ok( $content2 eq 'content2 scanned'           , "scanned file has correct content");

my @file5 = SL::File->get_all(%common_params, file_name => 'file3');
is( scalar @file5,                           1, "get_all file3: one currnt file found");
my $content5 = $file5[0]->get_content();
ok( $$content5 eq 'content3 new version'      , "file has correct current content");

my @file6 = SL::File->get_all_versions(%common_params, file_name => 'file3');
is( scalar @file6 ,                           2, "file3: two file versions found");
my $content6 = $file6[0]->get_content;
ok( $$content6 eq 'content3 new version'      , "file has correct current content");
$content6 = $file6[1]->get_content;
ok( $$content6 eq 'content3 created'          , "file has correct old content");

note('testing controller');
my $output;
open(my $outputFH, '>', \$output) or die; # This shouldn't fail
my $oldFH = select $outputFH;

$::form->{id} = $file1->id;
use SL::Controller::File;
SL::Controller::File->action_download();

select $oldFH;
close $outputFH;
my @lines = split "\n" , $output;
ok($lines[4] eq 'content1 uploaded', "controller download has correct content");

#some controller checks
$::form = Support::TestSetup->create_new_form;
$::form->{object_id}   = 12345678;
$::form->{object_type} = undef;
my $result='xx1';
eval {
  SL::Controller::File->check_object_params();
  $result = 'yy1';
  1;
} or do {
  $result = $@;
};
is(substr($result,0,14), "No object type", "controller error response 'No object type' ok");

$::form = Support::TestSetup->create_new_form;
$::form->{object_type} = 'sales_order';
$::form->{file_type}   = '';

$result='xx2';
eval {
  SL::Controller::File->check_object_params();
  $result='yy2';
  1;
} or do {
  $result=$@;
};
is(substr($result,0,12), "No file type", "controller error response 'No file type' ok");

sub clear_up {
  # Cleaning up may fail.
  eval {
    SL::File->delete_all(%common_params);
    unlink($scanner_file);
  };
}

}

clear_up();
done_testing;

1;
