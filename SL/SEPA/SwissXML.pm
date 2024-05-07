package SL::SEPA::SwissXML;

use strict;
use utf8;

use parent qw(SL::SEPA::XML);

use Carp;
use Encode;
use POSIX qw(strftime);
use XML::Writer;

use SL::Iconv;
use SL::SEPA::XML::SwissTransaction;

sub add_transaction {
  my $self = shift;

  foreach my $transaction (@_) {
    croak "Expecting hash reference." if (ref $transaction ne 'HASH');
    push @{ $self->{transactions} }, SL::SEPA::XML::SwissTransaction->new(%{ $transaction }, 'sepa' => $self);
  }

  return 1;
}

sub _group_transactions {
  my $self    = shift;

  my $grouped = {
    'sum_amount' => 0,
    'groups'     => { },
  };

  foreach my $transaction (@{ $self->{transactions} }) {
    my $key                      = $self->{grouped} ? join("\t", map { $transaction->get($_) } qw(src_bic src_iban execution_date is_sepa_payment)) : 'all';
    $grouped->{groups}->{$key} ||= {
      'sum_amount'   => 0,
      'transactions' => [ ],
    };

    push @{ $grouped->{groups}->{$key}->{transactions} }, $transaction;

    $grouped->{groups}->{$key}->{sum_amount} += $transaction->{amount};
    $grouped->{sum_amount}                   += $transaction->{amount};
  }

  return $grouped;
}

sub to_xml {
  my $self = shift;

  croak "No transactions added yet." if (!@{ $self->{transactions} });

  my $output = '';

  my $xml    = XML::Writer->new(OUTPUT      => \$output,
                                DATA_MODE   => 1,
                                DATA_INDENT => 2,
                                ENCODING    => 'utf-8');

  my @now       = localtime;
  # (removed time zone stuff in accordance with SIX examples)
  my $now_str   = strftime('%Y-%m-%dT%H:%M:%S', @now);

  my $payment_inf_id_counter = 1;
  my $transaction_id_counter = 1;

  my $grouped_transactions = $self->_group_transactions();

  # Note: the transaction->get function, respectively the encode function
  # that is used there produces garbled characters for example:
  # encode('UTF-8', '& & äöü <123>') -> &amp; &amp; Ã¤Ã¶Ã¼ &lt;123&gt;
  # not fully clear why, for now I'll omit the function in some places

  $xml->xmlDecl();

  $xml->startTag('Document',
                 'xmlns'              => "urn:iso:std:iso:20022:tech:xsd:pain.001.001.09",
                 'xmlns:xsi'          => 'http://www.w3.org/2001/XMLSchema-instance',
                 'xsi:schemaLocation' => "urn:iso:std:iso:20022:tech:xsd:pain.001.001.09 pain.001.001.09.ch.03.xsd");

  $xml->startTag('CstmrCdtTrfInitn');

  $xml->startTag('GrpHdr');
  $xml->dataElement('MsgId', $self->_restricted_identification_sepa1($self->{message_id}));
  $xml->dataElement('CreDtTm', $now_str);
  $xml->dataElement('NbOfTxs', scalar @{ $self->{transactions} });
  $xml->dataElement('CtrlSum', $self->_format_amount($grouped_transactions->{sum_amount}));

  $xml->startTag('InitgPty');
  $xml->dataElement('Nm', encode('UTF-8', substr($self->{company}, 0, 70)));
  # (details about the software)
  $xml->startTag('CtctDtls');
  $xml->startTag('Othr');
  $xml->dataElement('ChanlTp', 'NAME');
  $xml->dataElement('Id', 'Kivitendo');
  $xml->endTag('Othr');
  $xml->endTag('CtctDtls');
  # TODO (optional): get current kivitendo version
  # $xml->startTag('Othr');
  # $xml->dataElement('ChanlTp', 'VRSN');
  # $xml->dataElement('Id', '...');
  # $xml->endTag('Othr');
  $xml->endTag('InitgPty');

  $xml->endTag('GrpHdr');

  foreach my $key (keys %{ $grouped_transactions->{groups} }) {
    my $transaction_group  = $grouped_transactions->{groups}->{$key};
    my $master_transaction = $transaction_group->{transactions}->[0];

    $xml->startTag('PmtInf');

    my $payment_inf_id = 'PMTINF-' . sprintf('%010d', $payment_inf_id_counter);
    $xml->dataElement('PmtInfId', $payment_inf_id);

    $xml->dataElement('PmtMtd', 'TRF');

    # if batch booking true there will be "1 booking per group"
    # (according to swiss business rules specification)
    # I don't fully understand how there can be 1 booking for multiple transactions
    # furthermore in that case we should make sure there is only 1 currency in the group
    # (function _group_transactions)
    # so for now I'm setting this to false
    $xml->dataElement('BtchBookg', 'false');

    if ($master_transaction->get('is_sepa_payment')) {
      $xml->startTag('PmtTpInf');
      $xml->startTag('SvcLvl');
      $xml->dataElement('Cd', 'SEPA');
      $xml->endTag('SvcLvl');
      $xml->endTag('PmtTpInf');
    }

    $xml->startTag('ReqdExctnDt');
    $xml->dataElement('Dt', $master_transaction->get('execution_date'));
    $xml->endTag('ReqdExctnDt');
    $xml->startTag('Dbtr');
    # not using get here because it's garbling the characters
    $xml->dataElement('Nm', $self->{company});
    $xml->endTag('Dbtr');

    $xml->startTag('DbtrAcct');
    $xml->startTag('Id');
    $xml->dataElement('IBAN', $master_transaction->get('src_iban', 34));
    $xml->endTag('Id');
    $xml->endTag('DbtrAcct');

    $xml->startTag('DbtrAgt');
    $xml->startTag('FinInstnId');
    $xml->dataElement('BICFI', $master_transaction->get('src_bic', 20));
    $xml->endTag('FinInstnId');
    $xml->endTag('DbtrAgt');

    foreach my $transaction (@{ $transaction_group->{transactions} }) {
      $xml->startTag('CdtTrfTxInf');

      $xml->startTag('PmtId');

      # using a simple counter here, analog to examples from SIX
      my $instr_id = 'INSTRID-' .
        sprintf('%010d', $payment_inf_id_counter) . '-' .
        sprintf('%010d', $transaction_id_counter);
      $xml->dataElement('InstrId', $instr_id);

      $xml->dataElement('EndToEndId',
        $self->_restricted_identification_sepa1($transaction->get('end_to_end_id')));
      $xml->endTag('PmtId');

      $xml->startTag('Amt');
      $xml->startTag('InstdAmt', 'Ccy' => $transaction->{currency});
      $xml->characters($self->_format_amount($transaction->{amount}));
      $xml->endTag('InstdAmt');
      $xml->endTag('Amt');

      if ($transaction->{is_sepa_payment}) {
        $xml->startTag('CdtrAgt');
        $xml->startTag('FinInstnId');
        $xml->dataElement('BICFI', $transaction->{dst_bic});
        $xml->endTag('FinInstnId');
        $xml->endTag('CdtrAgt');
      }

      $xml->startTag('Cdtr');
      if ($transaction->{is_qrbill}) {
        $xml->dataElement('Nm', $transaction->{creditor_name});
        $xml->startTag('PstlAdr');
        # don't use empty elements here, according to SIX validator
        $xml->dataElement('StrtNm', $transaction->{creditor_street_name}) if $transaction->{creditor_street_name};
        $xml->dataElement('BldgNb', $transaction->{creditor_building_number}) if $transaction->{creditor_building_number};
        $xml->dataElement('PstCd', $transaction->{creditor_postal_code});
        $xml->dataElement('TwnNm', $transaction->{creditor_town_name});
        $xml->dataElement('Ctry', $transaction->{creditor_country});
        $xml->endTag('PstlAdr');
      } else {
        $xml->dataElement('Nm', $transaction->{company});
        if ($transaction->{has_creditor_address}) {
          $xml->startTag('PstlAdr');
          $xml->dataElement('StrtNm', $transaction->{creditor_street_name}) if $transaction->{creditor_street_name};
          $xml->dataElement('BldgNb', $transaction->{creditor_building_number}) if $transaction->{creditor_building_number};
          $xml->dataElement('PstCd', $transaction->{creditor_postal_code});
          $xml->dataElement('TwnNm', $transaction->{creditor_town_name});
          $xml->dataElement('Ctry', $transaction->{creditor_country});
          $xml->endTag('PstlAdr');
        }
      }
      $xml->endTag('Cdtr');

      $xml->startTag('CdtrAcct');
      $xml->startTag('Id');
      $xml->dataElement('IBAN', $transaction->get('dst_iban', 34));
      $xml->endTag('Id');
      $xml->endTag('CdtrAcct');

      $xml->startTag('RmtInf');
      if ($transaction->{end_to_end_id} =~ /^ENDTOENDID-(QRR|SCOR)$/) {
        $xml->startTag('Strd');
        $xml->startTag('CdtrRefInf');
        $xml->startTag('Tp');
        $xml->startTag('CdOrPrtry');
        if ($transaction->{end_to_end_id} eq 'ENDTOENDID-QRR') {
          $xml->dataElement('Prtry', 'QRR');
        } else {
          $xml->dataElement('Cd', 'SCOR');
        }
        $xml->endTag('CdOrPrtry');
        $xml->endTag('Tp');
        $xml->dataElement('Ref', $transaction->get('reference'));
        $xml->endTag('CdtrRefInf');
        if ($transaction->{unstructured_message}) {
          $xml->dataElement('AddtlRmtInf', $transaction->get('unstructured_message'));
        }
        $xml->endTag('Strd');
      } else {
        if ($transaction->{reference}) {
          $xml->dataElement('Ustrd', $transaction->get('reference', 140));
        }
      }
      $xml->endTag('RmtInf');

      $xml->endTag('CdtTrfTxInf');

      $transaction_id_counter++;
    }

    $xml->endTag('PmtInf');

    $payment_inf_id_counter++;
  }

  $xml->endTag('CstmrCdtTrfInitn');
  $xml->endTag('Document');
  $xml->end();

  return $output;
}

1;

# Local Variables:
# coding: utf-8
# End:
