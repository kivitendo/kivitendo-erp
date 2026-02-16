use strict;
use threads;
use lib 't';
use Support::Files;
use Sys::CPU;
use Test::More;
use Thread::Pool::Simple;
use SL::DB::Helper::Mappings;

# known broken upgrades, but so far in the past that we won't touch them now
my %white_list = map { $_ => 1 } qw(
  sql/Pg-upgrade2/add_file_version.pl
);

my @sql_upgrade_files = grep /^sql.Pg-upgrade2/ && !$white_list{$_}, @Support::Files::testitems;

if (eval { require PPI; 1 }) {
  plan tests => scalar(@sql_upgrade_files);
} else {
  plan skip_all => "PPI not installed";
}

my $fh;
{
    local $^W = 0;  # Don't complain about non-existent filehandles
    if (-e \*Test::More::TESTOUT) {
        $fh = \*Test::More::TESTOUT;
    } elsif (-e \*Test::Builder::TESTOUT) {
        $fh = \*Test::Builder::TESTOUT;
    } else {
        $fh = \*STDOUT;
    }
}

# prepare list of known Rose::DB::Object packages
my (undef, $package_names) = SL::DB::Helper::Mappings::get_package_names();
my %rdbo_packages = map { SL::DB::Helper::Mappings::get_package_for_table($_) => 1 } keys %$package_names;


sub test_file {
  my ($file) = @_;
  my $clean = 1;
  my $source;
  {
    # due to a bug in PPI it cannot determine the encoding of a source file by
    # use utf8; normaly this would be no problem but some people instist on
    # putting strange stuff into the source. as a workaround read in the source
    # with :utf8 layer and pass it to PPI by reference
    # there are still some latin chars, but it's not the purpose of this test
    # to find them, so warnings about it will be ignored
    local $^W = 0; # don't care about invalid chars in comments
    local $/ = undef;
    open my $fh, '<:utf8', $file or die $!;
    $source = <$fh>;
  }

  my $doc = PPI::Document->new(\$source) or do {
    print $fh "?: PPI error for file $file: " . PPI::Document::errstr() . "\n";
    ok 0, $file;
    next;
  };
  my $stmts = $doc->find('Statement::Include');

  for my $include (@{ $stmts || [] }) {
    # local can have valid uses like this, and our is extremely uncommon
    next unless $include->type eq 'use';

    my $module = $include->module;

    next unless $rdbo_packages{$module};

    $clean = 0;
    print $fh "?: $module\n";
  }

  ok $clean, $file;
}

my $pool = Thread::Pool::Simple->new(
  min    => 2,
  max    => Sys::CPU::cpu_count() + 1,
  do     => [ \&test_file ],
  passid => 0,
);

$pool->add($_) for @sql_upgrade_files;

$pool->join;

__END__

=pod

=head1 NO RDBO IN SQL UPGRADES

If you see this test failing, you likely wrote a perl database migration and
used SL::DB::* methods.

This is forbidden, because whenever the user executes the migration their
database and SL/DB/Metasetup states are out of sync and will likely break in
unexpected ways.

Please rewrite the migration to work with raw sql instead.
