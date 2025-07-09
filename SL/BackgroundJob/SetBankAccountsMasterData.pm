package SL::BackgroundJob::SetBankAccountsMasterData;

use strict;

use parent qw(SL::BackgroundJob::Base);

use SL::DBUtils;

sub run {
  my ($self, $db_obj)     = @_;

  my $data                = $db_obj->data_as_hash;

  die "No valid integer for months"  if $data->{months}    && $data->{months}     !~ /^[1-9][0-9]*$/;
  die "No valid value for overwrite" if $data->{overwrite} && $data->{overwrite}  !~ /^(0|1)$/;
  die "No valid value for dry_run"   if $data->{dry_run}   && $data->{dry_run}    !~ /^(0|1)$/;

  $self->{dry_run}   = $data->{dry_run}    ? 1               : 0;
  $self->{overwrite} = $data->{overwrite}  ? 1               : 0;
  $self->{months}    = $data->{months}     ? $data->{months} : 6;

  my (@updates_vendor, @updates_customer);

  foreach my $vc_type (qw(customer vendor)) {
    my $bank_vc = _get_bank_data_vc(vc => $vc_type, months => $self->{months});

    foreach my $bank_vc_entry (@{ $bank_vc }) {
      if ($bank_vc_entry->{remote_account_number}) {
        my $vc =  $vc_type eq 'customer'
                ? SL::DB::Customer->new(id => $bank_vc_entry->{customer_id})->load
                : SL::DB::Vendor  ->new(id => $bank_vc_entry->{vendor_id})  ->load;

        next if $vc->can('mandate_date_of_signature') && $vc->mandate_date_of_signature;
        next if $vc->iban && !$self->{overwrite};

        push @updates_customer, $vc->name . " -> " . $bank_vc_entry->{remote_account_number} if $vc_type eq 'customer';
        push @updates_vendor,   $vc->name . " -> " . $bank_vc_entry->{remote_account_number} if $vc_type eq 'vendor';

        next if $self->{dry_run};

        $vc->update_attributes(iban => $bank_vc_entry->{remote_account_number}, bic => $bank_vc_entry->{remote_bank_code});
      }
    }
  }
  my $msg = $self->{dry_run} ? "DRY RUN Updates: " : "Updates: ";
  $msg   .= "Customer: " . join (',', @updates_customer) . "\n Vendors: "  . join (',', @updates_vendor);

  return $msg;
}

sub _get_bank_data_vc {
  my (%params) = @_;

  die "Need a defined value for params(vc)"     unless $params{vc};
  die "Need a defined value for params(months)" unless $params{months};

  die "Need valid vc param, got:"     . $params{vc}     unless $params{vc}     =~ /^(customer|vendor)$/;
  die "Need valid months param, got:" . $params{months} unless $params{months} =~ /^[1-9][0-9]*$/;

  my $vc_id = $params{vc} . '_id';

  my $arap  =   $params{vc} eq 'customer' ? 'ar'
              : $params{vc} eq 'vendor'   ? 'ap'
              : undef;


  my $dbh = SL::DB->client->dbh;
  my $query = <<SQL;
  SELECT bt.remote_bank_code, bt.remote_account_number, $vc_id
  FROM $arap
  LEFT JOIN bank_transaction_acc_trans bta ON id = bta.${arap}_id
  LEFT JOIN bank_transactions bt ON bt.id = bta.bank_transaction_id
  WHERE $vc_id IN (SELECT DISTINCT $vc_id FROM $arap WHERE transdate > now() - interval '$params{months} month' AND paid = amount)
  AND bta.${arap}_id IS NOT NULL
  GROUP BY bt.remote_account_number,bt.remote_bank_code, $vc_id
  ORDER BY $vc_id
SQL

  my $result = selectall_hashref_query($::form, $dbh, $query);

  return $result;
}

1;

__END__

=encoding utf8

=head1 NAME

SL::BackgroundJob::SetBankAccountsMasterData —
Background job for setting IBAN and BIC for Customers and Vendors
regarding to the booked bank transactions for this companies.

=head1 SYNOPSIS

This background job searches all invoices which are paid by bank transactions
and gets the IBAN and BIC for those transactions.
If the IBAN and BICs in the master data are not yet set, they will be
set via this background jobs.

By default the job only adds IBAN and BIC for entries which have no
manual entry before.
The job accepts three parameters:

C<dry_run> -> No data will be changed, instead the changes will be
written to the job journal.

C<months> -> The intervall in months for which invoices are fetched, defaults
to 6 (months).

C<overwrite> -> If set to 1 values in the master data will be changed
even if they are already exists, except if a mandate_date_of_signature is
found. Those data sets won't be changed because kivitendo assumes that there
is a direct debit contract for exactly this account with this specific company.

The job is deactivated by default. Administrators of installations
where such a feature is wanted have to create a job entry manually.

=head1 AUTHOR

Jan Büren E<lt>jan@kivitendo.deE<gt>

=cut
