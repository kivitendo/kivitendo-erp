use Test::More;
use Test::Exception;

use strict;

use lib 't';
use utf8;

use Data::Dumper;
use File::Basename;
use File::Slurp;
use IO::Dir;
use SL::Util qw(snakify);

sub find_pms {
  my %dir;
  tie %dir, 'IO::Dir', $_[0];
  return sort grep { m/\.pm$/ } keys %dir;
}

my %no_db_ok          = map { ($_ => 1) } qw();
my %no_metasetup_ok   = map { ($_ => 1) } qw(Object.pm VC.pm);
my @dbs               = find_pms('SL/DB');
my @metasetups        = find_pms('SL/DB/MetaSetup');
my %metasetup_content = map { ($_ => scalar(read_file("SL/DB/MetaSetup/$_"))) } @metasetups;
my $all_content       = read_file('SL/DB/Helper/ALL.pm');
my $mapping_content   = read_file('SL/DB/Helper/Mappings.pm');

sub test_db_has_metasetup {
  foreach my $pm (@metasetups) {
    my $base = basename($pm);
    is(-f "SL/DB/MetaSetup/${base}" ? 1 : 0, $no_metasetup_ok{$base} ? 0 : 1, "$pm has entry in SL/DB/MetaSetup");
  }
}

sub test_metasetup_has_db {
  foreach my $pm (@metasetups) {
    my $base = basename($pm);
    is(-f "SL/DB/${base}" ? 1 : 0, $no_db_ok{$base} ? 0 : 1, "$pm has entry in SL/DB");
  }
}

sub test_db_included_in_all {
  foreach my $pm (@dbs) {
    my $base = basename($pm, '.pm');
    ok($all_content =~ m/\nuse\s+SL::DB::${base};/, "$pm has entry in SL::DB::Helper::ALL");
  }
}

sub test_use_in_all_exists_as_db {
  foreach my $package (map { m/^use\s+(.+?);/; $1 } grep { '^use SL::DB::' } split m/\n/, $all_content) {
    next unless $package =~ m/^SL::DB::(.+)/;
    my $file = $1;
    $file    =~ s{::}{/}g;
    ok(-f "SL/DB/${file}.pm", "'use $package' has entry in SL/DB");
  }
}

sub test_metasetup_has_table_to_class_mapping {
  my ($package_name_mapping) = $mapping_content =~ m/my\s*\%kivitendo_package_names\s*=\s*\((.+?)\n\)/s;
  ok($package_name_mapping, "found kivitendo_package_names in SL/DB/Helper/Mappings.pm");
  return unless $package_name_mapping;

  foreach my $pm (@metasetups) {
    my ($table) = $metasetup_content{$pm} =~ m{\n__PACKAGE__->meta->table\('(.+?)'\)};
    ok($table, "$pm has table setup");
    next unless $table;

    my ($schema) = $metasetup_content{$pm} =~ m{\n__PACKAGE__->meta->schema\('(.*?)'\)};
    $table       = "${schema}.${table}" if $schema;
    ok(!$schema || ($schema =~ m{^(?:auth|tax)$}), "$pm has either no schema or a known one");

    my $model               = basename($pm, '.pm');
    my $snaked_model        = snakify($model);
    my $maps_table_to_class = $package_name_mapping =~ m{\b'?\Q${table}\E'?\s*=>\s*\'(?:${snaked_model}|${model})\'};
    ok($maps_table_to_class, "$pm has mapping from table ${table} to class ${snaked_model} or ${model} in \%kivitendo_package_names");
  }
}

test_db_has_metasetup();
test_metasetup_has_db();
test_db_included_in_all();
test_use_in_all_exists_as_db();
test_metasetup_has_table_to_class_mapping();

done_testing();
