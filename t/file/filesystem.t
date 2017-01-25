use strict;
use Test::More tests => 11;

use lib 't';
use Support::TestSetup;
use Test::Exception;
use SL::File;
use SL::Dev::File;

Support::TestSetup::login();

my $db = SL::DB::Object->new->db;
$db->dbh->do("UPDATE defaults SET doc_files = 't'");
$db->dbh->do("UPDATE defaults SET doc_files_rootpath = '/var/tmp/kivifs'");

my $scannerfile = '/var/tmp/f2';

clear_up();
reset_state();

my $file1 = SL::Dev::File::create_uploaded( file_name => 'file1', file_contents => 'inhalt1 uploaded' );
my $file2 = SL::Dev::File::create_scanned(  file_name => 'file2', file_contents => 'inhalt2 scanned', file_path => $scannerfile );
my $file3 = SL::Dev::File::create_created(  file_name => 'file3', file_contents => 'inhalt3 created'    );
my $file4 = SL::Dev::File::create_created(  file_name => 'file3', file_contents => 'inhalt3 new version');

is( SL::Dev::File->get_all_count(),                    3,"total number of files created is 3");
ok( $file1->file_name                        eq 'file1' ,"file has right name");
my $content1 = $file1->get_content;
ok( $$content1 eq 'inhalt1 uploaded'                    ,"file has right content");

is( -f $scannerfile ? 1 : 0,                           0,"scanned document is moved from scanner");

$file2->delete;
is( -f $scannerfile ? 1 : 0,                           1,"scanned document is moved back to scanner");
my $content2 = File::Slurp::read_file($scannerfile);
ok( $content2 eq 'inhalt2 scanned'                      ,"scanned file has right content");

my @file5 = SL::Dev::File->get_all(file_name => 'file3');
is(   scalar( @file5),                                 1, "one actual file found");
my $content5 = $file5[0]->get_content();
ok( $$content5 eq 'inhalt3 new version'                 ,"file has right actual content");

my @file6 = SL::Dev::File->get_all_versions(file_name => 'file3');
is(   scalar( @file6),                                 2,"two file versions found");
$content5 = $file6[0]->get_content;
ok( $$content5 eq 'inhalt3 new version'                 ,"file has right actual content");
$content5 = $file6[1]->get_content;
ok( $$content5 eq 'inhalt3 created'                     ,"file has right old content");

print "\n\nController:\n";
# now test controller
#$::form->{object_id}  = 1;
#$::form->{object_type}= 'sales_order';
#$::form->{file_type}  = 'document';
$::form->{id}  = $file1->id;
print "id=".$::form->{id}."\n";
use SL::Controller::File;
SL::Controller::File->action_download();
$::form->{object_id}   = 12345678;
$::form->{object_type} = undef;
eval {
  SL::Controller::File->check_object_params();
  1;
} or do {
    print $@;
};
$::form->{object_type} ='xx';
$::form->{file_type} ='yy';
eval {
  SL::Controller::File->check_object_params();
  1;
} or do {
    print $@;
};

clear_up();
done_testing;

sub clear_up {
  SL::Dev::File->delete_all();
  unlink($scannerfile);
};

sub reset_state {
  my %params = @_;

};

1;
