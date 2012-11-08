#!/usr/bin/perl

use strict;

BEGIN {
  unshift @INC, "modules/override"; # Use our own versions of various modules (e.g. YAML).
  push    @INC, "modules/fallback"; # Only use our own versions of modules if there's no system version.
}

use CGI qw( -no_xhtml);
use Config::Std;
use Data::Dumper;
use Digest::MD5 qw(md5_hex);
use English qw( -no_match_vars );
use Getopt::Long;
use List::MoreUtils qw(any);
use Pod::Usage;
use Term::ANSIColor;

use SL::Auth;
use SL::DBUtils;
use SL::DB;
use SL::Form;
use SL::Locale;
use SL::LXDebug;
use SL::LxOfficeConf;
use SL::DB::Helper::ALL;
use SL::DB::Helper::Mappings;

my %blacklist     = SL::DB::Helper::Mappings->get_blacklist;
my %package_names = SL::DB::Helper::Mappings->get_package_names;

our $form;
our $auth;
our %lx_office_conf;

our $script =  __FILE__;
$script     =~ s:.*/::;

$OUTPUT_AUTOFLUSH       = 1;
$Data::Dumper::Sortkeys = 1;

our $meta_path = "SL/DB/MetaSetup";

my %config;

sub setup {

  SL::LxOfficeConf->read;

  my $login     = $config{login} || $::lx_office_conf{devel}{login};

  if (!$login) {
    error("No login found in config. Please provide a login:");
    usage();
  }

  $::lxdebug      = LXDebug->new();
  $::locale       = Locale->new("de");
  $::form         = new Form;
  $::auth         = SL::Auth->new();
  $::user         = User->new(login => $login);
  %::myconfig     = $auth->read_user(login => $login);
  $::request      = { cgi => CGI->new({}) };
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
    error("Error in execution for table '$table'");
    error("'$EVAL_ERROR'") if $config{verbose};
    return;
  }

  $definition =~ s/::AUTO::/::/g;
  my $full_definition = <<CODE;
# This file has been auto-generated. Do not modify it; it will be overwritten
# by $::script automatically.
$definition;
CODE

  my $meta_definition = <<CODE;
# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::${package};

use strict;

use SL::DB::MetaSetup::${package};

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

1;
CODE

  my $file_exists = -f $meta_file;
  if ($file_exists) {
    my $old_size    = -s $meta_file;
    my $orig_file   = do { local(@ARGV, $/) = ($meta_file); <> };
    my $old_md5     = md5_hex($orig_file);
    my $new_size    = length $full_definition;
    my $new_md5     = md5_hex($full_definition);
    if ($old_size == $new_size && $old_md5 == $new_md5) {
      notice("No changes in $meta_file, skipping.") if $config{verbose};
      return;
    }

    show_diff(\$orig_file, \$full_definition) if $config{show_diff};
  }

  if (!$config{nocommit}) {
    open my $out, ">", $meta_file || die;
    print $out $full_definition;
  }

  notice("File '$meta_file' " . ($file_exists ? 'updated' : 'created') . " for table '$table'");

  if (! -f $file) {
    if (!$config{nocommit}) {
      open my $out, ">", $file || die;
      print $out $meta_definition;
    }

    notice("File '$file' created as well.");
  }
}

sub parse_args {
  my ($options) = @_;
  GetOptions(
    'login|user=s'      => \ my $login,
    all                 => \ my $all,
    'no-commit|dry-run' => \ my $nocommit,
    help                => sub { pod2usage(verbose => 99, sections => 'NAME|SYNOPSIS|OPTIONS') },
    verbose             => \ my $verbose,
    diff                => \ my $diff,
  );

  $options->{login}    = $login if $login;
  $options->{all}      = $all;
  $options->{nocommit} = $nocommit;
  $options->{verbose}  = $verbose;

  if ($diff) {
    if (eval { require Text::Diff; 1 }) {
      $options->{show_diff} = 1;
    } else {
      error('Could not load Text::Diff. Sorry, no diffs for you.');
    }
  }
}

sub show_diff {
   my ($text_a, $text_b) = @_;

   my %colors = (
     '+' => 'green',
     '-' => 'red',
   );

   Text::Diff::diff($text_a, $text_b, { OUTPUT => sub {
     for (split /\n/, $_[0]) {
       print colored($_, $colors{substr($_, 0, 1)}), $/;
     }
   }});
}

sub usage {
  pod2usage(verbose => 99, sections => 'SYNOPSIS');
}

sub make_tables {
  my @tables;
  if ($config{all}) {
    my $db  = SL::DB::create(undef, 'LXOFFICE');
    @tables =
      map { $package_names{LXOFFICE}->{$_} ? "$_=" . $package_names{LXOFFICE}->{$_} : $_ }
      grep { my $table = $_; !any { $_ eq $table } @{ $blacklist{LXOFFICE} } }
      $db->list_tables;
  } elsif (@ARGV) {
    @tables = @ARGV;
  } else {
    error("You specified neither --all nor any specific tables.");
    usage();
  }

  @tables;
}

sub error {
  print STDERR colored(shift, 'red'), $/;
}

sub notice {
  print @_, $/;
}

parse_args(\%config);
setup();
my @tables = make_tables();

for my $table (@tables) {
  # add default model name unless model name is given or no defaults exists
  $table .= '=' . $package_names{LXOFFICE}->{lc $table} if $table !~ /=/ && $package_names{LXOFFICE}->{lc $table};

  process_table($table);
}

1;

__END__

=encoding utf-8

=head1 NAME

rose_auto_create_model - mana Rose::DB::Object classes for Lx-Office

=head1 SYNOPSIS

  scripts/rose_create_model.pl --login login table1[=package1] [table2[=package2] ...]
  scripts/rose_create_model.pl --login login [--all|-a]

  # updates all models
  scripts/rose_create_model.pl --login login --all

  # updates only customer table, login taken from config
  scripts/rose_create_model.pl customer

  # updates only parts table, package will be Part
  scripts/rose_create_model.pl parts=Part

  # try to update parts, but don't do it. tell what would happen in detail
  scripts/rose_create_model.pl --no-commit --verbose parts

=head1 DESCRIPTION

Rose::DB::Object comes with a nice function named auto initialization with code
generation. The documentation of Rose describes it like this:

I<[...] auto-initializing metadata at runtime by querying the database has many
caveats. An alternate approach is to query the database for metadata just once,
and then generate the equivalent Perl code which can be pasted directly into
the class definition in place of the call to auto_initialize.>

I<Like the auto-initialization process itself, perl code generation has a
convenient wrapper method as well as separate methods for the individual parts.
All of the perl code generation methods begin with "perl_", and they support
some rudimentary code formatting options to help the code conform to you
preferred style. Examples can be found with the documentation for each perl_*
method.>

I<This hybrid approach to metadata population strikes a good balance between
upfront effort and ongoing maintenance. Auto-generating the Perl code for the
initial class definition saves a lot of tedious typing. From that point on,
manually correcting and maintaining the definition is a small price to pay for
the decreased start-up cost, the ability to use the class in the absence of a
database connection, and the piece of mind that comes from knowing that your
class is stable, and won't change behind your back in response to an "action at
a distance" (i.e., a database schema update).>

Unfortunately this reads easier than it is, since classes need to go into the
right package and directory, certain stuff needs to be adjusted and table names
need to be translated into their class names. This script will wrap all that
behind a few simple options.

In the most basic version, just give it a login and a table name, and it will
load the schema information for this table and create the appropriate class
files, or update them if already present.

Each table has two associated files. A C<SL::DB::MetaSetup::*> class, which is
a perl version of the schema definition, and a C<SL::DB::*> class file. The
first one will be updated if the schema changes, the second one will only be
created if it does not exist.

=head1 OPTIONS

=over 4

=item C<--login, -l LOGIN>

=item C<--user, -u LOGIN>

Provide a login. If not present the login is loaded from the config key
C<devel/login>. If that too is not found, an error is thrown.

=item C<--all, -a>

Process all tables from the database. Only those that are blacklistes in
L<SL::DB::Helper::Mappings> are excluded.

=item C<--no-commit, -n>

=item C<--dry-run>

Do not write back generated files. This will do everything as usual but not
actually modify any file.

=item C<--diff>

Displays diff for selected file, if file is present and newer file is
different. Beware, does not imply C<--no-commit>.

=item C<--help, -h>

Print this help.

=item C<--verbose, -v>

Prints extra information, such as skipped files that were not changed and
errors where the auto initialization failed.

=back

=head1 BUGS

None yet.

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
