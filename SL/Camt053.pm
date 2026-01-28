package SL::Camt053;

use strict;
use warnings;

use XML::LibXML;
use DateTime;
use SL::Helper::DateTime;

my $namespace_re = qr/urn:iso:std:iso:20022:tech:xsd:camt\.053\.001\.(\d+)/;


# XML XPath expressions for global metadata
my %dom_xpaths = (
  message_id       => '/ns:Document/ns:BkToCstmrStmt/ns:GrpHdr/ns:MsgId',
  created_at       => '/ns:Document/ns:BkToCstmrStmt/ns:GrpHdr/ns:CreDtTm',
  date_from        => '/ns:Document/ns:BkToCstmrStmt/ns:Stmt/ns:TrToDt/ns:FrDtTm',
  date_to          => '/ns:Document/ns:BkToCstmrStmt/ns:Stmt/ns:TrToDt/ns:ToDtTm',
  balance          => '/ns:Document/ns:BkToCstmrStmt/ns:Bal',                 # at least 2 in DK: OBBD and CLPD
  stmt_id          => '/ns:Document/ns:BkToCstmrStmt/ns:Stmt/ns:Id',
  account_number   => '/ns:Document/ns:BkToCstmrStmt/ns:Stmt/ns:Acct/ns:Id/ns:IBAN | /ns:Document/ns:BkToCstmrStmt/ns:Stmt/ns:Acct/ns:Id/ns:Othr/ns:Id',
  bic              => '/ns:Document/ns:BkToCstmrStmt/ns:Stmt/ns:Acct/ns:Svcr/ns:FinInstnId/ns:BIC | /ns:Document/ns:BkToCstmrStmt/ns:Stmt/ns:Acct/ns:Svcr/ns:FinInstnId/ns:BICFI', # BIC in 02, BICFI in 08-13
  account_name     => '/ns:Document/ns:BkToCstmrStmt/ns:Stmt/ns:Acct/ns:Nm',
  items            => '/ns:Document/ns:BkToCstmrStmt/ns:Stmt/ns:Ntry',
);

my %balance_xpaths = (
  tp           => './ns:Tp/ns:CdOrPrtry/ns:Cd', # balance type, one of 10 types, important for us: OPBD (start of reporting period), CLPD (end of reporting period)
  amount       => './ns:Amt',
  currency     => './ns:Amt/@Ccy',
  credit_debit => './ns:CdtDbtInd',   # CRDT or DBIT
  date         => './ns:Dt/ns:Dt',
);

my %entry_xpaths = (
  transdate   => './ns:BookgDt/ns:Dt',
  valutadate  => './ns:ValDt/ns:Dt',
  type_code   => './ns:Sts | ./ns:Sts/ns:Cd',
  batch       => './ns:NtryDtls/ns:Btch',
  tx_details  => './ns:NtryDtls/ns:TxDtls',
);

my %transaction_details_xpaths = (
  name          => './ns:NtryDtls/ns:TxDtls/ns:RltdPties/ns:Dbtr/ns:Nm | ./ns:NtryDtls/ns:TxDtls/ns:RltdPties/ns:Cdtr/ns:Nm',
  reference     => [
    './ns:NtryDtls/ns:TxDtls/ns:RmtInf/ns:Strd/ns:CdtrRefInf/ns:Ref',
    './ns:NtryDtls/ns:TxDtls/ns:Refs/ns:InstrId',
  ],
  purpose       => [
    './ns:NtryDtls/ns:TxDtls/ns:RmtInf/ns:Ustrd',
    './ns:NtryDtls/ns:TxDtls/ns:RmtInf/ns:Strd/ns:CdtrRefInf/ns:Ref',
    #    './ns:NtryDtls/ns:TxDtls',
  ],
  payment_ref   => [
    './ns:NtryDtls/ns:TxDtls/ns:RtrInf/ns:Ustrd',
    './ns:NtryDtls/ns:TxDtls/ns:RtrInf/ns:AddtlInf',
    './ns:NtryDtls/ns:TxDtls/ns:AddtlNtryInf',
    './ns:NtryDtls/ns:TxDtls/ns:Refs/ns:InstrId',
  ],
  end_to_end_id  => './ns:NtryDtls/ns:TxDtls/ns:Refs/ns:EndToEndId',
  account_number => './ns:NtryDtls/ns:TxDtls/ns:RltdPties/ns:DbtrAcct/ns:Id/ns:IBAN | ./ns:NtryDtls/ns:TxDtls/ns:RltdPties/ns:CdtrAcct/ns:Id/ns:IBAN',
  bank_code      => './ns:NtryDtls/ns:TxDtls/ns:RltdAgts/ns:DbtrAgt/ns:FinInstnId/ns:BIC | ./ns:NtryDtls/ns:TxDtls/ns:RltdAgts/ns:CdtrAgt/ns:FinInstnId/ns:BIC | ./ns:NtryDtls/ns:TxDtls/ns:RltdAgts/ns:DbtrAgt/ns:FinInstnId/ns:BICFI | ./ns:NtryDtls/ns:TxDtls/ns:RltdAgts/ns:CdtrAgt/ns:FinInstnId/ns:BICFI',
);

my %batch_details_xpaths = (
  amount                 => "./ns:AmntDtls/ns:TxAmt",
  currency               => './ns:AmntDtls/ns:TxAmt@Ccy',
  reference              => "./ns:Refs/ns:InstrId",
  end_to_end_id          => "./ns:Refs/ns:EndToEndId",
  remote_name            => "./ns:RltdPties/ns:Cdtr/ns:Nm | ./ns:RltdPties/ns:Dbtr/ns:Nm",
  remote_bank_code       => "./ns:RltdAgts/ns:CdtrAgt/ns:FinInstnId/ns:BIC | ./ns:RltdAgts/ns:DbtrAgt/ns:FinInstnId/ns:BIC | ./ns:RltdAgts/ns:CdtrAgt/ns:FinInstnId/ns:BICFI | ./ns:RltdAgts/ns:DbtrAgt/ns:FinInstnId/ns:BICFI",
  remote_account_number  => "./ns:RltdPties/ns:CdtrAcct/ns:Id/ns:IBAN | ./ns:RltdPties/ns:DbtrAcct/ns:Id/ns:IBAN",
  purpose                => "./ns:RmtInf/ns:Ustrd | ./ns:AddtlTxInf",
);

sub parse_file {
  my ($class, $filename) = @_;

  my $dom = eval {
    XML::LibXML->load_xml(location => $filename, expand_entities => 0);
  } or do {
    my $e = $@;
    die "can't load camt.053 file: $e";
  };

  _parse($dom);
}

sub parse_xml {
  my ($class, $xml_data) = @_;

  my $dom = eval {
    XML::LibXML->load_xml(string => $xml_data, expand_entities => 0);
  } or do {
    my $e = $@;
    die "can't load camt.053 data: $e";
  };

  _parse($dom);
}

sub _parse {
  my ($dom) = @_;

  # find namespace and check against whitelist
  my $root = $dom->documentElement;
  my $ns = $root->namespaceURI;
  my $camt_version;

  if ($ns =~ $namespace_re) {
    $camt_version = $1;
  } else {
    die "unknown version or not a camt.053 export. unrecoglinzed namespace: $ns";
  }

  my $xc = XML::LibXML::XPathContext->new;
  $xc->registerNs(ns => $ns);
  # return ($dom, $xc, \%dom_xpaths);

  my $id       = $xc->find($dom_xpaths{message_id}, $dom);

  my @entries = $xc->findnodes($dom_xpaths{items}, $dom);
  my @transactions;
  my $line_number = 0;

  for my $entry (@entries) {
    my $booking_type = $xc->find($entry_xpaths{type_code}, $entry);
    if (!$booking_type || $booking_type ne 'BOOK') {
      # other booking types are only allowed in 052 or 054 but contain things like "INFO" (informational, not a real transaction) and "PDNG" (pending, not yet booked)
      next;
    }

    my $amount                = $xc->findvalue($balance_xpaths{amount}, $entry);
    my $debit_credit          = $xc->find($balance_xpaths{credit_debit}, $entry);
    my $sign                  = $debit_credit eq 'DBIT' ? -1 : 1;
    my $currency              = $xc->find($balance_xpaths{currency}, $entry) || SL::DB::Currency->get_default_currency;
    my $transdate             = DateTime->from_ymd($xc->find($entry_xpaths{transdate},  $entry));
    my $valutadate            = DateTime->from_ymd($xc->find($entry_xpaths{valutadate}, $entry)),
    my $local_account_number  = $xc->find($dom_xpaths{account_number}, $entry);
    my $local_bank_code       = $xc->find($dom_xpaths{bic}, $entry);
    my $remote_name           = $xc->find($transaction_details_xpaths{name}, $entry);
    my $remote_bank_code      = $xc->find($transaction_details_xpaths{bank_code}, $entry);
    my $remote_account_number = $xc->find($transaction_details_xpaths{account_number}, $entry);

    my $purpose               = join "", map $_->to_literal, $xc->findnodes(join(' | ', @{$transaction_details_xpaths{purpose}}), $entry);
    my $reference             = join " ", map $_->to_literal, $xc->findnodes(join(' | ', @{$transaction_details_xpaths{reference}}), $entry);
    my $end_to_end_id         = $xc->find($transaction_details_xpaths{end_to_end_id}, $entry);

    my %transaction = (
      currency              => $currency,
      valutadate            => $valutadate,
      transdate             => $transdate,
      amount                => $sign * $amount,
      reference             => $reference,
      transaction_code      => undef,                    # swift transaction codes don't exist in Camt053
      local_bank_code       => $local_bank_code,
      local_account_number  => $local_account_number,
      end_to_end_id         => $end_to_end_id,
      purpose               => $purpose,
      remote_name           => $remote_name,
      remote_bank_code      => $remote_bank_code,
      remote_account_number => $remote_account_number,
    );

    my $batch = $xc->find($entry_xpaths{batch}, $entry);
    $transaction{line_number} = ++$line_number;
    push @transactions, \%transaction;
  }

  return @transactions;
}

# transaction_code gibt es nicht mehr
# stattdessen eine kombination aus Ntry/BkTxCd/Dmn/Fmly/Cd (swift code wie PMNT - payment) und SubFmlyCd (sub code ICDT - incoming credit transfer)
# alternativ Ntry/BkTxCd/Prtry/Cd (166 - alter code) und Ntry/BkTxCd/Prtry/Issr (DE - deutsche norm) mit :81: freitext in NryDtls/TxDtks/AddtnlTxInf


# balance types:
#


1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::CAMT053 - Parser for ISO 20022 cash management format 053: bank to customer statement

=head1 SYNOPSIS

  use SL::CAMT053;

  my @transactions = SL::CAMT053->parse($xml_data);
  my @transactions = SL::CAMT053->parse_file($filename);

=head1 GLOSSARY

=head2 Balance Types

=over 4

CLAV - Closing balance of amount of money that is at the disposal of the account owner on the date specified.
CLBD - Balance of the account at the end of the pre-agreed account reporting period. It is the sum of the opening booked balance at the beginning of the period and all entries booked to the account during the pre-agreed account reporting period.
FWAV - Forward available balance of money that is at the disposal of the account owner on the date specified.
INFO - Balance for informational purposes.
ITAV - Available balance calculated in the course of the account servicer's business day, at the time specified, and subject to further changes during the business day. The interim balance is calculated on the basis of booked credit and debit items during the calculation time/period specified.
ITBD - Balance calculated in the course of the account servicer's business day, at the time specified, and subject to further changes during the business day. The interim balance is calculated on the basis of booked credit and debit items during the calculation time/period specified.
OPAV - Opening balance of amount of money that is at the disposal of the account owner on the date specified.
OPBD - Book balance of the account at the beginning of the account reporting period. It always equals the closing book balance from the previous report.
PRCD - Balance of the account at the previously closed account reporting period. The opening booked balance for the new period has to be equal to this balance. Usage: the previously booked closing balance should equal (inclusive date) the booked closing balance of the date it references and equal the actual booked opening balance of the current date.
XPCD - Balance, composed of booked entries and pending items known at the time of calculation, which projects the end of day balance if everything is booked on the account and no other entry is posted.

=back

=head2 Other Arcane Abbreviations

Rmt - Remote
Ustrd - Unstructred Reference
Cdtr - Creditor
Dbtr - Debitor
Prtry - Proprietary, used whenever something is defined by the issuing institute or program
Cd - Code
Nm - Name
Agt - Agent - usually meaning the credit institute
RltdPties - Related Parties

=head1 QUIRKS

- camt.053.001.02 has BIC while camt.053.001.08 and higher have BICFI
- <Btch> is not yet supported
- reference isn't standardized and likely broken
- some files seem to have an iso:20023 namespace despite camt being in iso:20022. iso:20023 is about safety of solid biofuel pellets...
- storno indicator exists but is currently unused

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@googlemail.comE<gt>

=cut
