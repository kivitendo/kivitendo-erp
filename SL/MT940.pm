package SL::MT940;

use strict;
use warnings;

use Data::Dumper;
use DateTime;
use Encode;
use File::Slurp qw(read_file);

sub _join_entries {
  my ($parts, $from, $to, $separator) = @_;

  $separator //= ' ';

  return
    join $separator,
    grep { $_ }
    map  { s{^\s+|\s+$}{}g; $_ }
    grep { $_ }
    map  { $parts->{$_} }
    ($from..$to);
}

sub parse {
  my ($class, $file_name) = @_;

  my ($local_bank_code, $local_account_number, %transaction, @transactions, @lines);
  my $line_number = 0;

  my $store_transaction = sub {
    if (%transaction) {
      push @transactions, { %transaction };
      %transaction = ();
    }
  };

  foreach my $line (read_file($file_name)) {
    chomp $line;
    $line = Encode::decode('UTF-8', $line);
    $line =~ s{\r+}{};
    $line_number++;

    if (@lines && ($line =~ m{^\%})) {
      $lines[-1]->[0] .= substr($line, 1);

    } else {
      push @lines, [ $line, $line_number ];
    }
  }

  foreach my $line (@lines) {
    if ($line->[0] =~ m{^:25:(\d+)/(\d+)}) {
      $local_bank_code      = $1;
      $local_account_number = $2;

    } elsif ($line->[0] =~ m{^:61: (\d{2}) (\d{2}) (\d{2}) (\d{2}) (\d{2}) (C|D|RC|RD) (.) (\d+) (?:, (\d*))? N (.{3}) (.*)}x) {
      #                       1       2       3       4       5       6                7   8          9         10     11
      # :61:2008060806CR952,N051NONREF

      $store_transaction->();

      my $valuta_year      = $1 * 1 + 2000;
      my $valuta_month     = $2;
      my $valuta_day       = $3;
      my $trans_month      = $4;
      my $trans_day        = $5;
      my $debit_credit     = $6;
      my $currency         = $7;
      my $amount1          = $8;
      my $amount2          = $9 || 0;
      my $transaction_code = $10;
      my $reference        = $11;

      my $valuta_date      = DateTime->new_local(year => $valuta_year, month => $valuta_month, day => $valuta_day);
      my $trans_date       = DateTime->new_local(year => $valuta_year, month => $trans_month,  day => $trans_day);
      my $diff             = $valuta_date->subtract_datetime($trans_date);
      my $trans_year_diff  = $diff->months < 6           ?  0
                           : $valuta_date  > $trans_date ?  1
                           :                               -1;
      $trans_date          = DateTime->new_local(year => $valuta_year + $trans_year_diff, month => $trans_month,  day => $trans_day);
      my $sign             = ($debit_credit eq 'D') || ($debit_credit eq 'RC') ? -1 : 1;
      $reference           =~ s{//.*}{};
      $reference           = '' if $reference eq 'NONREF';

      %transaction = (
        line_number          => $line->[1],
        currency             => $currency,
        valutadate           => $valuta_date,
        transdate            => $trans_date,
        amount               => ($amount1 * 1 + ($amount2 / (10 ** length($amount2))))* $sign,
        reference            => $reference,
        transaction_code     => $transaction_code,
        local_bank_code      => $local_bank_code,
        local_account_number => $local_account_number,
      );

    } elsif (%transaction && ($line->[0] =~ m{^:86:})) {
      if ($line->[0] =~ m{^:86:\d+\?(.+)}) {
        # structured
        my %parts = map { ((substr($_, 0, 2) // '0') * 1 => substr($_, 2)) } split m{\?}, $1;

        $transaction{purpose}               = _join_entries(\%parts, 20, 29);
        $transaction{remote_name}           = _join_entries(\%parts, 32, 33, '');
        $transaction{remote_bank_code}      = $parts{30};
        $transaction{remote_account_number} = $parts{31};

      } else {
        # unstructured
        $transaction{purpose} = substr($line->[0], 5);
      }

      $store_transaction->();
    }
  }

  $store_transaction->();

  return @transactions;
}

1;
