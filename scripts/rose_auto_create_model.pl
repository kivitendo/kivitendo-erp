#!/usr/bin/perl

use strict;

BEGIN {
  use FindBin;

  unshift(@INC, $FindBin::Bin . '/../modules/override'); # Use our own versions of various modules (e.g. YAML).
  push   (@INC, $FindBin::Bin . '/..');                  # '.' will be removed from @INC soon.
}

use CGI qw( -no_xhtml);
use Config::Std;
use Data::Dumper;
use Digest::MD5 qw(md5_hex);
use English qw( -no_match_vars );
use Getopt::Long;
use List::MoreUtils qw(apply none uniq);
use List::UtilsBy qw(partition_by);
use Pod::Usage;
use Rose::DB::Object 0.809;
use Term::ANSIColor;

use SL::Auth;
use SL::DBUtils;
use SL::DB;
use SL::Form;
use SL::InstanceConfiguration;
use SL::Locale;
use SL::LXDebug;
use SL::LxOfficeConf;
use SL::DB::Helper::ALL;
use SL::DB::Helper::Mappings;

chdir($FindBin::Bin . '/..');

my %blacklist     = SL::DB::Helper::Mappings->get_blacklist;
my %package_names = SL::DB::Helper::Mappings->get_package_names;

our $form;
our $auth;
our %lx_office_conf;

our $script =  __FILE__;
$script     =~ s{.*/}{};

$OUTPUT_AUTOFLUSH       = 1;
$Data::Dumper::Sortkeys = 1;

our $meta_path    = "SL/DB/MetaSetup";
our $manager_path = "SL/DB/Manager";

my %config;

# Maps column names in tables to foreign key relationship names.  For
# example:
#
# »follow_up_access« contains a column named »who«. Rose normally
# names the resulting relationship after the class the target table
# uses. In this case the target table is »employee« and the
# corresponding class SL::DB::Employee. The resulting relationship
# would be named »employee«.
#
# In order to rename this relationship we have to map »who« to
# e.g. »granted_by«:
#   follow_up_access => { who => 'granted_by' },

our %foreign_key_name_map     = (
  KIVITENDO                   => {
    oe                        => { payment_id => 'payment_terms', },
    ar                        => { payment_id => 'payment_terms', },
    ap                        => { payment_id => 'payment_terms', },

    orderitems                => { parts_id => 'part', trans_id => 'order', },
    reclamation_items         => { parts_id => 'part' },
    delivery_order_items      => { parts_id => 'part' },
    invoice                   => { parts_id => 'part' },
    follow_ups                => { created_by => 'created_by_employee', },
    follow_up_access          => { who => 'with_access', what => 'to_follow_ups_by', },

    periodic_invoices_configs => { oe_id => 'order', email_recipient_contact_id => 'email_recipient_contact' },
    reconciliation_links      => { acc_trans_id => 'acc_trans' },

    assembly                  => { parts_id => 'part', id => 'assembly_part' },
    assortment_items          => { parts_id => 'part' },

    dunning                   => { trans_id => 'invoice', fee_interest_ar_id => 'fee_interest_invoice' },
  },
);

sub setup {

  SL::LxOfficeConf->read;

  my $client     = $config{client} || $::lx_office_conf{devel}{client};
  my $new_client = $config{new_client};

  if (!$client && !$new_client) {
    error("No client found in config. Please provide a client:");
    usage();
  }

  $::lxdebug       = LXDebug->new();
  $::lxdebug->disable_sub_tracing;
  $::locale        = Locale->new("de");
  $::form          = new Form;
  $::instance_conf = SL::InstanceConfiguration->new;
  $form->{script}  = 'rose_meta_data.pl';

  if ($new_client) {
    $::auth       = SL::Auth->new(unit_tests_database => 1);
    $client       = 1;
    drop_and_create_test_database();
  } else {
    $::auth       = SL::Auth->new();
  }

  if (!$::auth->set_client($client)) {
    error("No client with ID or name '$client' found in config. Please provide a client:");
    usage();
  }

  foreach (($meta_path, $manager_path)) {
    mkdir $_ unless -d;
  }
}

sub fix_relationship_names {
  my ($domain, $table, $fkey_text) = @_;

  if ($fkey_text !~ m/key_columns \s+ => \s+ \{ \s+ ['"]? ( [^'"\s]+ ) /x) {
    die "fix_relationship_names: could not extract the key column for domain/table $domain/$table; foreign key definition text:\n${fkey_text}\n";
  }

  my $column_name = $1;
  my %changes     = map { %{$_} } grep { $_ } ($foreign_key_name_map{$domain}->{ALL}, $foreign_key_name_map{$domain}->{$table});

  if (my $desired_name = $changes{$column_name}) {
    $fkey_text =~ s/^ \s\s [^\s]+ \b/  ${desired_name}/msx;
  }

  return $fkey_text;
}

sub process_table {
  my ($domain, $table, $package) = @_;
  my $schema     = '';
  ($schema, $table) = split(m/\./, $table) if $table =~ m/\./;
  $package       =  ucfirst($package || $table);
  $package       =~ s/_+(.)/uc($1)/ge;
  my $meta_file  =  "${meta_path}/${package}.pm";
  my $mngr_file  =  "${manager_path}/${package}.pm";
  my $file       =  "SL/DB/${package}.pm";

  my $schema_str = $schema ? <<CODE : '';
__PACKAGE__->meta->schema('$schema');
CODE

  eval <<CODE;
    package SL::DB::AUTO::$package;
    use parent qw(SL::DB::Object);

    __PACKAGE__->meta->table('$table');
    $schema_str
    __PACKAGE__->meta->auto_initialize;

CODE

  if ($EVAL_ERROR) {
    error("Error in execution for table '$table'");
    error("'$EVAL_ERROR'") unless $config{quiet};
    return;
  }

  my %args = (indent => 2, use_setup => 0);

  my $definition =  "SL::DB::AUTO::$package"->meta->perl_class_definition(%args);
  $definition =~ s/\n+__PACKAGE__->meta->initialize;\n+/\n\n/;
  $definition =~ s/::AUTO::/::/g;


  # Sort column definitions alphabetically
  if ($definition =~ m/__PACKAGE__->meta->columns\( \n (.+?) \n \);/msx) {
    my ($start, $end)  = ($-[1], $+[1]);
    my $sorted_columns = join "\n", sort split m/\n/, $1;
    substr $definition, $start, $end - $start, $sorted_columns;
  }

  # patch foreign keys
  my $foreign_key_definition = "SL::DB::AUTO::$package"->meta->perl_foreign_keys_definition(%args);
  $foreign_key_definition =~ s/::AUTO::/::/g;

  if ($foreign_key_definition && ($definition =~ /\Q$foreign_key_definition\E/)) {
    # These positions refer to the whole setup call, not just the
    # parameters/actual relationship definitions.
    my ($start, $end) = ($-[0], $+[0]);

    # Match the function parameters = the actual relationship
    # definitions
    next unless $foreign_key_definition =~ m/\(\n(.+)\n\)/s;

    my ($list_start, $list_end) = ($-[0], $+[0]);

    # Split the whole chunk on double new lines. The resulting
    # elements are one relationship each. Then fix the relationship
    # names and sort them by their new names.
    my @new_foreign_keys = sort map { fix_relationship_names($domain, $table, $_) } split m/\n\n/m, $1;

    # Replace the function parameters = the actual relationship
    # definitions with the new ones.
    my $sorted_foreign_keys = "(\n" . join("\n\n", @new_foreign_keys) . "\n)";
    substr $foreign_key_definition, $list_start, $list_end - $list_start, $sorted_foreign_keys;

    # Replace the whole setup call in the auto-generated output with
    # our new version.
    substr $definition, $start, $end - $start, $foreign_key_definition;
  }

  $definition =~ s/(meta->table.*)\n/$1\n$schema_str/m if $schema;
  $definition =~ s{^use base}{use parent}m;

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
use SL::DB::Manager::${package};

__PACKAGE__->meta->initialize;

1;
CODE

  my $file_exists = -f $meta_file;
  if ($file_exists) {
    my $old_size    = -s $meta_file;
    my $orig_file   = do { local(@ARGV, $/) = ($meta_file); <> };
    my $old_md5     = md5_hex($orig_file);
    my $new_size    = length $full_definition;
    my $new_md5     = md5_hex($full_definition);
    if ($old_size == $new_size && $old_md5 eq $new_md5) {
      notice("No changes in $meta_file, skipping.") unless $config{quiet};
      return;
    }

    show_diff(\$orig_file, \$full_definition) if $config{show_diff};
  }

  if (!$config{nocommit}) {
    open my $out, ">", $meta_file || die;
    print $out $full_definition;
  }

  notice("File '$meta_file' " . ($file_exists ? 'updated' : 'created') . " for table '$table'");

  return if -f $file;

  if (!$config{nocommit}) {
    open my $out, ">", $file || die;
    print $out $meta_definition;
  }

  notice("File '$file' created as well.");

  return if -f $mngr_file;

  if (!$config{nocommit}) {
    open my $out, ">", $mngr_file || die;
    print $out <<EOT;
# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Manager::${package};

use strict;

use parent qw(SL::DB::Helper::Manager);

sub object_class { 'SL::DB::${package}' }

__PACKAGE__->make_manager_methods;

1;
EOT
  }

  notice("File '$mngr_file' created as well.");
}

sub parse_args {
  my ($options) = @_;
  GetOptions(
    'client=s'          => \ my $client,
    'test-client'       => \ my $use_test_client,
    all                 => \ my $all,
    'db=s'              => \ my $db,
    'no-commit|dry-run' => \ my $nocommit,
    help                => sub { pod2usage(verbose => 99, sections => 'NAME|SYNOPSIS|OPTIONS') },
    quiet               => \ my $quiet,
    diff                => \ my $diff,
  );

  $options->{client}     = $client;
  $options->{new_client} = $use_test_client;
  $options->{all}        = $all;
  $options->{db}         = $db;
  $options->{nocommit}   = $nocommit;
  $options->{quiet}      = $quiet;
  $options->{color}      = -t STDOUT ? 1 : 0;

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
       if ($config{color}) {
         print colored($_, $colors{substr($_, 0, 1)}), $/;
       } else {
         print $_, $/;
       }
     }
   }});
}

sub usage {
  pod2usage(verbose => 99, sections => 'SYNOPSIS');
}

sub list_all_tables {
  my ($db) = @_;

  my @schemas = (undef, uniq apply { s{\..*}{} } grep { m{\.} } keys %{ $package_names{KIVITENDO} });
  my @tables;

  foreach my $schema (@schemas) {
    $db->schema($schema);
    push @tables, map { $schema ? "${schema}.${_}" : $_ } $db->list_tables;
  }

  $db->schema(undef);

  return @tables;
}

sub make_tables {
  my %tables_by_domain;
  if ($config{all}) {
    my @domains = $config{db} ? (uc $config{db}) : sort keys %package_names;

    foreach my $domain (@domains) {
      my $db  = SL::DB::create(undef, $domain);
      $tables_by_domain{$domain} = [ grep { my $table = $_; none { $_ eq $table } @{ $blacklist{$domain} } } list_all_tables($db) ];
      $db->disconnect;
    }

  } elsif (@ARGV) {
    %tables_by_domain = partition_by {
      my ($domain, $table) = split m{:};
      $table ? uc($domain) : 'KIVITENDO';
    } @ARGV;

    foreach my $tables (values %tables_by_domain) {
      s{.*:}{} for @{ $tables };
    }

  } else {
    error("You specified neither --all nor any specific tables.");
    usage();
  }

  return %tables_by_domain;
}

sub error {
  print STDERR colored(shift, 'red'), $/;
}

sub notice {
  print @_, $/;
}

sub check_errors_in_package_names {
  foreach my $domain (sort keys %package_names) {
    my @both = grep { $package_names{$domain}->{$_} } @{ $blacklist{$domain} || [] };
    next unless @both;

    print "Error: domain '$domain': The following table names are present in both the black list and the package name hash: ", join(' ', sort @both), "\n";
    exit 1;
  }
}

sub drop_and_create_test_database {
  my $db_cfg          = $::lx_office_conf{'testing/database'} || die 'testing/database missing';

  my @dbi_options = (
    'dbi:Pg:dbname=' . $db_cfg->{template} . ';host=' . $db_cfg->{host} . ';port=' . $db_cfg->{port},
    $db_cfg->{user},
    $db_cfg->{password},
    SL::DBConnect->get_options,
  );

  $::auth->reset;
  my $dbh_template = SL::DBConnect->connect(@dbi_options) || BAIL_OUT("No database connection to the template database: " . $DBI::errstr);
  my $auth_dbh     = $::auth->dbconnect(1);

  if ($auth_dbh) {
    notice("Database exists; dropping");
    $auth_dbh->disconnect;

    dbh_do($dbh_template, "DROP DATABASE \"" . $db_cfg->{db} . "\"", message => "Database could not be dropped");
  }

  notice("Creating database");

  dbh_do($dbh_template, "CREATE DATABASE \"" . $db_cfg->{db} . "\" TEMPLATE \"" . $db_cfg->{template} . "\" ENCODING 'UNICODE'", message => "Database could not be created");
  $dbh_template->disconnect;

  notice("Creating initial schema");

  @dbi_options = (
    'dbi:Pg:dbname=' . $db_cfg->{db} . ';host=' . $db_cfg->{host} . ';port=' . $db_cfg->{port},
    $db_cfg->{user},
    $db_cfg->{password},
    SL::DBConnect->get_options(PrintError => 0, PrintWarn => 0),
  );

  my $dbh           = SL::DBConnect->connect(@dbi_options) || BAIL_OUT("Database connection failed: " . $DBI::errstr);
  $::auth->{dbh} = $dbh;
  my $dbupdater  = SL::DBUpgrade2->new(form => $::form, return_on_error => 1, silent => 1);
  my $coa        = 'Germany-DATEV-SKR03EU';

  apply_dbupgrade($dbupdater, $dbh, "sql/lx-office.sql");
  apply_dbupgrade($dbupdater, $dbh, "sql/${coa}-chart.sql");

  dbh_do($dbh, qq|UPDATE defaults SET coa = '${coa}', accounting_method = 'cash', profit_determination = 'income', inventory_system = 'periodic', curr = 'EUR'|);
  dbh_do($dbh, qq|CREATE TABLE schema_info (tag TEXT, login TEXT, itime TIMESTAMP DEFAULT now(), PRIMARY KEY (tag))|);

  notice("Creating initial auth schema");

  $dbupdater = SL::DBUpgrade2->new(form => $::form, return_on_error => 1, auth => 1);
  apply_dbupgrade($dbupdater, $dbh, 'sql/auth_db.sql');

  apply_upgrades(auth => 1, dbh => $dbh);

  $::auth->reset;

  notice("Creating client, user, group and employee");

  dbh_do($dbh, qq|DELETE FROM auth.clients|);
  dbh_do($dbh, qq|INSERT INTO auth.clients (id, name, dbhost, dbport, dbname, dbuser, dbpasswd, is_default) VALUES (1, 'Unit-Tests', ?, ?, ?, ?, ?, TRUE)|,
         bind => [ @{ $db_cfg }{ qw(host port db user password) } ]);
  dbh_do($dbh, qq|INSERT INTO auth."user"         (id,        login)    VALUES (1, 'unittests')|);
  dbh_do($dbh, qq|INSERT INTO auth."group"        (id,        name)     VALUES (1, 'Vollzugriff')|);
  dbh_do($dbh, qq|INSERT INTO auth.clients_users  (client_id, user_id)  VALUES (1, 1)|);
  dbh_do($dbh, qq|INSERT INTO auth.clients_groups (client_id, group_id) VALUES (1, 1)|);
  dbh_do($dbh, qq|INSERT INTO auth.user_group     (user_id,   group_id) VALUES (1, 1)|);

  my %config                 = (
    default_printer_id       => '',
    template_format          => '',
    default_media            => '',
    email                    => 'unit@tester',
    tel                      => '',
    dateformat               => 'dd.mm.yy',
    show_form_details        => '',
    name                     => 'Unit Tester',
    signature                => '',
    hide_cvar_search_options => '',
    numberformat             => '1.000,00',
    favorites                => '',
    copies                   => '',
    menustyle                => 'v3',
    fax                      => '',
    stylesheet               => 'design40.css',
    mandatory_departments    => 0,
    countrycode              => 'de',
  );

  my $sth = $dbh->prepare(qq|INSERT INTO auth.user_config (user_id, cfg_key, cfg_value) VALUES (1, ?, ?)|) || BAIL_OUT($dbh->errstr);
  dbh_do($dbh, $sth, bind => [ $_, $config{$_} ]) for sort keys %config;
  $sth->finish;

  $sth = $dbh->prepare(qq|INSERT INTO auth.group_rights (group_id, "right", granted) VALUES (1, ?, TRUE)|) || BAIL_OUT($dbh->errstr);
  dbh_do($dbh, $sth, bind => [ $_ ]) for sort $::auth->all_rights;
  $sth->finish;

  dbh_do($dbh, qq|INSERT INTO employee (id, login, name) VALUES (1, 'unittests', 'Unit Tester')|);

  $::auth->set_client(1) || BAIL_OUT("\$::auth->set_client(1) failed");
  %::myconfig = $::auth->read_user(login => 'unittests');

  apply_upgrades(dbh => $dbh);
}

sub apply_upgrades {
  my %params            = @_;
  my $dbupdater         = SL::DBUpgrade2->new(form => $::form, return_on_error => 1, auth => $params{auth});
  my @unapplied_scripts = $dbupdater->unapplied_upgrade_scripts($params{dbh});

  my $all = @unapplied_scripts;
  my $i;
  for my $script (@unapplied_scripts) {
    ++$i;
    print "\rUpgrade $i/$all";
    apply_dbupgrade($dbupdater, $params{dbh}, $script);
  }
  print " - done.\n";
}

sub apply_dbupgrade {
  my ($dbupdater, $dbh, $control_or_file) = @_;

  my $file    = ref($control_or_file) ? ("sql/Pg-upgrade2" . ($dbupdater->{auth} ? "-auth" : "") . "/$control_or_file->{file}") : $control_or_file;
  my $control = ref($control_or_file) ? $control_or_file                                                                        : undef;

  my $error = $dbupdater->process_file($dbh, $file, $control);

  die("Error applying $file: $error") if $error;
}

sub dbh_do {
  my ($dbh, $query, %params) = @_;

  if (ref($query)) {
    return if $query->execute(@{ $params{bind} || [] });
    die($dbh->errstr);
  }

  return if $dbh->do($query, undef, @{ $params{bind} || [] });

  die($params{message} . ": " . $dbh->errstr) if $params{message};
  die("Query failed: " . $dbh->errstr . " ; query: $query");
}

parse_args(\%config);
setup();
check_errors_in_package_names();

my %tables_by_domain = make_tables();

foreach my $domain (keys %tables_by_domain) {
  my @tables         = @{ $tables_by_domain{$domain} };
  my @unknown_tables = grep { !$package_names{$domain}->{$_} } @tables;
  if (@unknown_tables) {
    error("The following tables do not have entries in \%SL::DB::Helper::Mappings::${domain}_package_names: " . join(' ', sort @unknown_tables));
    exit 1;
  }

  process_table($domain, $_, $package_names{$domain}->{$_}) for @tables;
}

1;

__END__

=encoding utf-8

=head1 NAME

rose_auto_create_model - mana Rose::DB::Object classes for kivitendo

=head1 SYNOPSIS

  scripts/rose_auto_create_model.pl OPTIONS TARGET

  # use other client than devel.client
  scripts/rose_auto_create_model.pl --test-client TARGET
  scripts/rose_auto_create_model.pl --client name-or-id TARGET

  # TARGETS:
  # updates all models
  scripts/rose_auto_create_model.pl --all [--db db]

  # updates only customer table, login taken from config
  scripts/rose_auto_create_model.pl customer

  # updates only parts table, package will be Part
  scripts/rose_auto_create_model.pl parts=Part

  # try to update parts, but don't do it. tell what would happen in detail
  scripts/rose_auto_create_model.pl --no-commit parts

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

Each table has three associated files. A C<SL::DB::MetaSetup::*>
class, which is a perl version of the schema definition, a
C<SL::DB::*> class file and a C<SL::DB::Manager::*> manager class
file. The first one will be updated if the schema changes, the second
and third ones will only be created if it they do not exist.

=head1 DATABASE NAMES AND TABLES

If you want to generate the data for specific tables only then you
have to list them on the command line. The format is
C<db-name:table-name>. The part C<db-name:> is optional and defaults
to C<KIVITENDO:> – which means the tables in the default kivitendo
database.

Valid database names are keys in the hash returned by
L<SL::DB::Helper::Mappings/get_package_names>.

=head1 OPTIONS

=over 4

=item C<--test-client, -t>

Use the C<testing/database> to create a new testing database, and connect to
the first client there. Overrides C<client>.

If neither C<test-client> nor C<client> are set, the config key C<devel/client>
will be used.

=item C<--client, -c CLIENT>

Provide a client whose database settings are used. C<CLIENT> can be either a
database ID or a client's name.

If neither C<test-client> nor C<client> are set, the config key C<devel/client>
will be used.

=item C<--all, -a>

Process all tables from the database. Only those that are blacklistes in
L<SL::DB::Helper::Mappings> are excluded.

=item C<--db db>

In combination with C<--all> causes all tables in the specific
database to be processed, not in all databases.

=item C<--no-commit, -n>

=item C<--dry-run>

Do not write back generated files. This will do everything as usual but not
actually modify any file.

=item C<--diff>

Displays diff for selected file, if file is present and newer file is
different. Beware, does not imply C<--no-commit>.

=item C<--help, -h>

Print this help.

=item C<--quiet, -q>

Does not print extra information, such as skipped files that were not
changed and errors where the auto initialization failed.

=back

=head1 BUGS

None yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>,
Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
