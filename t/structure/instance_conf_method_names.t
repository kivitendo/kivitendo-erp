#!/usr/bin/perl

use strict;
use lib 't';
use File::Find;
use File::Slurp;
use Test::More;

my %default_columns;
my %compatibility_functions = map { ($_ => 1) } qw(address);

sub read_default_columns {
  my $content   =  read_file('SL/DB/MetaSetup/Default.pm');
  my ($columns) =  $content =~ m{\n__PACKAGE__->meta->columns\((.+?)\n\)}s;
  $columns      =~ s/=>.*?\},|\n//g;
  $columns      =~ s/ +/ /g;
  $columns      =~ s/^\s+|\s+$//g;

  return map { ($_ => 1) } split m/ +/, $columns;
}

sub test_file_content {
  my ($file)  = @_;
  my $content = read_file($file);

  while ($content =~ m{(?:INSTANCE_CONF\.|\$(?:main)?::instance_conf->)get_([a-z0-9_]+)}gi) {
    ok($default_columns{$1} || $compatibility_functions{$1}, "'get_${1}' is a valid method call on \$::instance_conf in $file");
  }
}

%default_columns = read_default_columns();
my @files        = glob('*.pl');
find(sub { push(@files, $File::Find::name) if $_ =~ /\.pm$/;   }, 'SL');
find(sub { push(@files, $File::Find::name) if $_ =~ /\.pl$/;   },  qw(bin/mozilla sql/Pg-upgrade2 scripts));
find(sub { push(@files, $File::Find::name) if $_ =~ /\.html$/; }, 'templates/design40_webpages');

test_file_content($_) for @files;

done_testing();
