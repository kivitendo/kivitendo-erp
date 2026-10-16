#!/usr/bin/perl

use strict;
use warnings;
use utf8;

BEGIN {
  use FindBin;

  unshift(@INC, $FindBin::Bin . '/../modules/override'); # Use our own versions of various modules (e.g. YAML).
  push   (@INC, $FindBin::Bin . '/..');
  push   (@INC, $FindBin::Bin . '/../modules/fallback'); # Only use our own versions of modules if there's no system version.
}

use Getopt::Long;
use Pod::Usage;

use SL::LxOfficeConf;
SL::LxOfficeConf->read;

use SL::Auth;
use SL::DBUtils;
use SL::DB;
use SL::DB::Invoice;
use SL::DB::PurchaseInvoice;
use SL::Form;
use SL::InstanceConfiguration;
use SL::Locale;
use SL::LXDebug;

chdir($FindBin::Bin . '/..');

my ($client, $commit, $help);
GetOptions(
  'client|c=s' => \$client,
  'commit'     => \$commit,
  'help|h'     => \$help,
) or pod2usage(2);
pod2usage(-exitstatus => 0, -verbose => 2) if $help;
pod2usage(2)                               if !$client;

$::lxdebug       = LXDebug->new;
$::locale        = Locale->new($::lx_office_conf{system}->{language});
$::form          = Form->new;
$::auth          = SL::Auth->new;
die "Cannot find client with ID or name '$client'\n" if !$::auth->set_client($client);
$::instance_conf = SL::InstanceConfiguration->new;

my $dbh = SL::DB->client->dbh;

my $skonto_charts = <<SQL;
  SELECT skonto_sales_chart_id    FROM tax WHERE skonto_sales_chart_id    IS NOT NULL
  UNION
  SELECT skonto_purchase_chart_id FROM tax WHERE skonto_purchase_chart_id IS NOT NULL
SQL

# Skonto lines of invoices without project.
my $invoice_lines = selectall_hashref_query($::form, $dbh, <<SQL);
  SELECT acc.acc_trans_id, acc.trans_id, (ap.id IS NOT NULL) AS is_purchase
  FROM acc_trans acc
  LEFT JOIN ar ON (ar.id = acc.trans_id)
  LEFT JOIN ap ON (ap.id = acc.trans_id)
  WHERE acc.chart_id IN ($skonto_charts)
    AND acc.project_id IS NULL
    AND (ar.id IS NOT NULL OR ap.id IS NOT NULL)
SQL

# Skonto tax corrections: GL bookings with exactly two lines, one on a skonto
# chart and one on a tax chart, that are linked to exactly one invoice and have
# no project yet. Canceled corrections are left out, because their reversal
# isn't linked to the invoice and would stay without project.
my $gl_lines = selectall_hashref_query($::form, $dbh, <<SQL);
  WITH corrections AS (
    SELECT acc.trans_id
    FROM acc_trans acc
    JOIN gl ON (gl.id = acc.trans_id AND NOT gl.storno)
    GROUP BY acc.trans_id
    HAVING count(*) = 2
       AND bool_or(acc.chart_id IN ($skonto_charts))
       AND bool_or(acc.chart_id IN (SELECT chart_id FROM tax))
       AND bool_and(acc.project_id IS NULL)
  ),
  links AS (
    SELECT to_id, min(from_id) AS from_id, min(from_table) AS from_table
    FROM record_links
    WHERE to_table = 'gl' AND from_table IN ('ar', 'ap')
    GROUP BY to_id
    HAVING count(*) = 1
  )
  SELECT acc.acc_trans_id, links.from_id AS trans_id, (links.from_table = 'ap') AS is_purchase
  FROM corrections
  JOIN links         ON (links.to_id  = corrections.trans_id)
  JOIN acc_trans acc ON (acc.trans_id = corrections.trans_id)
SQL

my %lines_by_invoice;
foreach my $line (@$invoice_lines, @$gl_lines) {
  push @{ $lines_by_invoice{$line->{trans_id}}{lines} }, $line->{acc_trans_id};
  $lines_by_invoice{$line->{trans_id}}{is_purchase} = $line->{is_purchase};
}

my (%count, %skipped);

# A dry run doesn't update anything, so it doesn't lock rows either.
$dbh->begin_work if $commit;

foreach my $trans_id (sort { $a <=> $b } keys %lines_by_invoice) {
  my $entry      = $lines_by_invoice{$trans_id};
  my $class      = $entry->{is_purchase} ? 'SL::DB::PurchaseInvoice' : 'SL::DB::Invoice';
  my $invoice    = $class->new(id => $trans_id)->load(speculative => 1);
  my $project_id = $invoice && $invoice->skonto_project_id;

  if (!$project_id) {
    $skipped{invoices}++;
    $skipped{lines} += scalar @{ $entry->{lines} };
    next;
  }

  $count{invoices}++;
  $count{lines} += !$commit ? scalar @{ $entry->{lines} } : do_query($::form, $dbh,
    'UPDATE acc_trans SET project_id = ? WHERE project_id IS NULL AND acc_trans_id = ANY(?)',
    $project_id, $entry->{lines});
}

$dbh->commit if $commit;

printf "Skonto lines found:     %d (invoices: %d, tax corrections: %d)\n",
  scalar(@$invoice_lines) + scalar(@$gl_lines), scalar(@$invoice_lines), scalar(@$gl_lines);
printf "Lines with project:     %d of %d invoices\n", $count{lines}   // 0, $count{invoices}   // 0;
printf "Lines without project:  %d of %d invoices (no single project or invoice deleted)\n",
  $skipped{lines} // 0, $skipped{invoices} // 0;
print $commit ? "Changes saved.\n" : "Dry run, nothing saved. Use --commit to save.\n";

__END__

=encoding utf-8

=head1 NAME

set_skonto_projects.pl - Set the project of skonto bookings from their invoice

=head1 SYNOPSIS

  scripts/set_skonto_projects.pl --client <client> [--commit]

=head1 DESCRIPTION

Skonto booked automatically for bank transactions or SEPA exports used to be
booked without project. Newer versions book it with the project of the
invoice (see C<skonto_project_id> in L<SL::DB::Helper::Payment>).

This script sets the project for older bookings the same way:

=over 2

=item * skonto lines (charts of the skonto settings of the taxes) of sales and
purchase invoices without project

=item * the lines of skonto tax corrections: GL bookings with two lines, one on
a skonto chart and one on a tax chart, which are linked to exactly one invoice,
aren't canceled and have no project at all

=back

Lines whose invoice has no single project stay without project. Only the
project is set, amounts and charts are not changed.

Without C<--commit> nothing is saved and the script only shows what it would
do.

=head1 OPTIONS

=over 4

=item C<--client>, C<-c>

Name or ID of the client.

=item C<--commit>

Save the changes.

=back

=cut
