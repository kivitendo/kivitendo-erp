#!/usr/bin/perl

use strict;

BEGIN {
  unshift @INC, "modules/override"; # Use our own versions of various modules (e.g. YAML).
  push    @INC, "modules/fallback"; # Only use our own versions of modules if there's no system version.
}

use CGI qw( -no_xhtml);
use Data::Dumper;
use English qw( -no_match_vars );
use List::MoreUtils qw(any);

use SL::Auth;
use SL::DBUtils;
use SL::DB;
use SL::Form;
use SL::Locale;
use SL::LXDebug;
use SL::DB::Helper::ALL;
use SL::DB::Helper::Mappings;

our $form;
our $cgi;
our $auth;

our $script =  __FILE__;
$script     =~ s:.*/::;

$OUTPUT_AUTOFLUSH       = 1;
$Data::Dumper::Sortkeys = 1;

our $meta_path = "SL/DB/MetaSetup";

sub setup {
  if (@ARGV < 2) {
    print "Usage: $PROGRAM_NAME login table1[=package1] [table2[=package2] ...]\n";
    print "   or  $PROGRAM_NAME login [--all|-a] [--sugar|-s]\n";
    exit 1;
  }

  my $login     = shift @ARGV;

  $::userspath  = "users";
  $::templates  = "templates";
  $::sendmail   = "| /usr/sbin/sendmail -t";

  $::lxdebug    = LXDebug->new();

  require "config/lx-erp.conf";
  require "config/lx-erp-local.conf" if -f "config/lx-erp-local.conf";

  # locale messages
  $::locale       = Locale->new("de");
  $::form         = new Form;
  $::cgi          = new CGI('');
  $::auth         = SL::Auth->new();

  $::user         = User->new($login);

  %::myconfig     = $auth->read_user($login);
  $form->{script} = 'rose_meta_data.pl';
  $form->{login}  = $login;

  map { $form->{$_} = $::myconfig{$_} } qw(stylesheet charset);

  mkdir $meta_path unless -d $meta_path;
}

sub process_table {
  my @spec       =  split(/=/, shift, 2);
  my $table      =  $spec[0];
  my $schema     = '';
  ($schema, $table) = split(m/\./, $table) if $table =~ m/\./;
  my $package    =  ucfirst($spec[1] || $spec[0]);
  $package       =~ s/_+(.)/uc($1)/ge;
  my $meta_file  =  "${meta_path}/${package}.pm";
  my $file       =  "SL/DB/${package}.pm";

  $schema        = <<CODE if $schema;
    __PACKAGE__->meta->schema('$schema');
CODE

  my $definition =  eval <<CODE;
    package SL::DB::AUTO::$package;
    use SL::DB::Object;
    use base qw(SL::DB::Object);

    __PACKAGE__->meta->table('$table');
$schema
    __PACKAGE__->meta->auto_initialize;

    __PACKAGE__->meta->perl_class_definition(indent => 2); # , braces => 'bsd'
CODE

  if ($EVAL_ERROR) {
    print STDERR "Error in execution for table '$table': $EVAL_ERROR";
    return;
  }

  $definition =~ s/::AUTO::/::/g;

  my $file_exists = -f $meta_file;

  open(OUT, ">$meta_file") || die;
  print OUT <<CODE;
# This file has been auto-generated. Do not modify it; it will be overwritten
# by $::script automatically.
$definition;
CODE
  close OUT;

  print "File '$meta_file' " . ($file_exists ? 'updated' : 'created') . " for table '$table'\n";

  if (! -f $file) {
    open(OUT, ">$file") || die;
    print OUT <<CODE;
# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::${package};

use strict;

use SL::DB::MetaSetup::${package};

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

1;
CODE
    close OUT;

    print "File '$file' created as well.\n";
  }
}

setup();

my %blacklist     = SL::DB::Helper::Mappings->get_blacklist;
my %package_names = SL::DB::Helper::Mappings->get_package_names;

my @tables = ();
if (($ARGV[0] eq '--all') || ($ARGV[0] eq '-a') || ($ARGV[0] eq '--sugar') || ($ARGV[0] eq '-s')) {
  my ($type, $prefix) = ($ARGV[0] eq '--sugar') || ($ARGV[0] eq '-s') ? ('SUGAR', 'sugar_') : ('LXOFFICE', '');
  my $db              = SL::DB::create(undef, $type);
  @tables             = map  { $package_names{$type}->{$_} ? "${_}=" . $package_names{$type}->{$_} : $prefix ? "${_}=${prefix}${_}" : $_ }
                        grep { my $table = $_; !any { $_ eq $table } @{ $blacklist{$type} } }
                        $db->list_tables;

} else {
  @tables = @ARGV;
}

foreach my $table (@tables) {
  # add default model name unless model name is given or no defaults exists
  $table .= '=' . $package_names{LXOFFICE}->{lc $table} if $table !~ /=/ && $package_names{LXOFFICE}->{lc $table};

  process_table($table);
}
