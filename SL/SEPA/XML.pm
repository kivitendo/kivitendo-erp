package SL::SEPA::XML;

use strict;
use utf8;

use Carp;
use Encode;
use List::MoreUtils qw(any);
use List::Util qw(first sum);
use POSIX qw(strftime);
use XML::Writer;

use SL::Iconv;
use SL::SEPA::XML::Transaction;

use constant V3_0_0 => 3_000_000;
use constant V3_8_0 => 3_800_000;

sub get_supported_versions {
  return (
    versions => [
      { id => V3_0_0(), description => "v3.0.0" },
      { id => V3_8_0(), description => "v3.8.0" },
    ],
    default => get_default_version(),
  );
}

sub get_default_version {
  my $today          = DateTime->today_local;
  my $cutoff_v3_8_0  = DateTime->new_local(year => 2025, month => 10, day => 1);

  return V3_8_0() if $today >= $cutoff_v3_8_0;
  return V3_0_0();
}

sub is_version_valid {
  shift while @_ && ref($_[0]);

  my $id       = $_[0];
  my %versions = get_supported_versions();

  return any { $_->{id} == $id } @{ $versions{versions} };
}

sub new {
  my $class = shift;
  my $self  = {};

  bless $self, $class;

  $self->_init(@_);

  return $self;
}

sub _init {
  my $self              = shift;
  my %params            = @_;

  $self->{transactions} = [];
  $self->{src_charset}  = 'UTF-8';
  $self->{grouped}      = 0;
  $self->{version}      = get_default_version();

  map { $self->{$_} = $params{$_} if (exists $params{$_}) } qw(src_charset company creditor_id message_id grouped collection version);

  $self->{iconv} = SL::Iconv->new($self->{src_charset}, "UTF-8") || croak "Unsupported source charset $self->{src_charset}.";

  my $missing_parameter = first { !$self->{$_} } qw(company message_id);
  croak "Missing parameter: $missing_parameter" if ($missing_parameter);
  croak "Missing parameter: creditor_id"        if !$self->{creditor_id} && $self->{collection};
  croak "Invalid parameter: version"            if !is_version_valid($self->{version});

  map { $self->{$_} = $self->_replace_special_chars($self->{iconv}->convert($self->{$_})) } qw(company message_id creditor_id);
}

sub add_transaction {
  my $self = shift;

  foreach my $transaction (@_) {
    croak "Expecting hash reference." if (ref $transaction ne 'HASH');
    push @{ $self->{transactions} }, SL::SEPA::XML::Transaction->new(%{ $transaction }, 'sepa' => $self);
  }

  return 1;
}

sub _replace_special_chars {
  my $self = shift;
  my $text = shift;

  my %special_chars = (
    'ä' => 'ae',
    'ö' => 'oe',
    'ü' => 'ue',
    'Ä' => 'Ae',
    'Ö' => 'Oe',
    'Ü' => 'Ue',
    'ß' => 'ss',
    '&' => '+',
    '`' => '\'',
    );

  map { $text =~ s/$_/$special_chars{$_}/g; } keys %special_chars;

  # for all other non ascii chars 'OLÉ S.L.' and 'Årdberg AB'!
  use Text::Unidecode qw(unidecode);
  $text = unidecode($text);

  return $text;
}

sub _format_amount {
  my $self   = shift;
  my $amount = shift;

  return sprintf '%.02f', $amount;
}

sub _group_transactions {
  my $self    = shift;

  my $grouped = {
    'sum_amount' => 0,
    'groups'     => { },
  };

  foreach my $transaction (@{ $self->{transactions} }) {
    my $key                      = $self->{grouped} ? join("\t", map { $transaction->get($_) } qw(src_bic src_iban execution_date)) : 'all';
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

sub _restricted_identification_sepa1 {
  my ($self, $string) = @_;

  $string =~ s/[^A-Za-z0-9\+\?\/\-:\(\)\.,' ]//g;
  return substr $string, 0, 35;
}

sub _restricted_identification_sepa2 {
  my ($self, $string) = @_;

  $string =~ s/[^A-Za-z0-9\+\?\/\-:\(\)\.,']//g;
  return substr $string, 0, 35;
}

sub _emit_cdtr_scheme_id {
  my ($self, $xml) = @_;

  $xml->startTag('CdtrSchmeId');
  $xml->startTag('Id');
  $xml->startTag('PrvtId');
  $xml->startTag('Othr');
  $xml->dataElement('Id', encode('UTF-8', substr($self->{creditor_id}, 0, 35)));
  $xml->startTag('SchmeNm');
  $xml->dataElement('Prtry', 'SEPA');
  $xml->endTag('SchmeNm');
  $xml->endTag('Othr');
  $xml->endTag('PrvtId');
  $xml->endTag('Id');
  $xml->endTag('CdtrSchmeId');
}

sub to_xml {
  my $self = shift;

  croak "No transactions added yet." if (!@{ $self->{transactions} });

  my $output = '';

  my $xml    = XML::Writer->new(OUTPUT      => \$output,
                                DATA_MODE   => 1,
                                DATA_INDENT => 2,
                                ENCODING    => 'UTF-8');

  my @now       = localtime;
  my $time_zone = strftime "%z", @now;
  my $now_str   = strftime('%Y-%m-%dT%H:%M:%S', @now) . substr($time_zone, 0, 3) . ':' . substr($time_zone, 3, 2);

  my $is_coll   = $self->{collection};
  my $cd_src    = $is_coll ? 'Cdtr'              : 'Dbtr';
  my $cd_dst    = $is_coll ? 'Dbtr'              : 'Cdtr';
  my $pain_elmt = $is_coll ? 'CstmrDrctDbtInitn' : 'CstmrCdtTrfInitn';
  my @pii_base  = (strftime('PII%Y%m%d%H%M%S', @now), rand(1000000000));
  my $pain_id   = $is_coll && ($self->{version}  == V3_0_0()) ? 'pain.008.001.02'
                : $is_coll && ($self->{version}  == V3_8_0()) ? 'pain.008.001.08'
                : !$is_coll && ($self->{version} == V3_0_0()) ? 'pain.001.001.03'
                : !$is_coll && ($self->{version} == V3_8_0()) ? 'pain.001.001.09'
                :                                               die("programming error: version not handled for pain ID");
  my $bic_elt   = $self->{version} == V3_0_0() ? 'BIC'
                : $self->{version} == V3_8_0() ? 'BICFI'
                :                                die("programming error: version not handled for BIC element name");

  my $grouped_transactions = $self->_group_transactions();

  $xml->xmlDecl();

  $xml->startTag('Document',
                 'xmlns'              => "urn:iso:std:iso:20022:tech:xsd:${pain_id}",
                 'xmlns:xsi'          => 'http://www.w3.org/2001/XMLSchema-instance',
                 'xsi:schemaLocation' => "urn:iso:std:iso:20022:tech:xsd:${pain_id} ${pain_id}.xsd");

  $xml->startTag($pain_elmt);

  $xml->startTag('GrpHdr');
  $xml->dataElement('MsgId', encode('UTF-8', $self->_restricted_identification_sepa1($self->{message_id})));
  $xml->dataElement('CreDtTm', $now_str);
  $xml->dataElement('NbOfTxs', scalar @{ $self->{transactions} });
  $xml->dataElement('CtrlSum', $self->_format_amount($grouped_transactions->{sum_amount}));

  $xml->startTag('InitgPty');
  $xml->dataElement('Nm', encode('UTF-8', substr($self->{company}, 0, 70)));
  $xml->endTag('InitgPty');

  $xml->endTag('GrpHdr');

  foreach my $key (keys %{ $grouped_transactions->{groups} }) {
    my $transaction_group  = $grouped_transactions->{groups}->{$key};
    my $master_transaction = $transaction_group->{transactions}->[0];

    $xml->startTag('PmtInf');
    $xml->dataElement('PmtInfId', sprintf('%s%010d', @pii_base));
    $pii_base[1]++;
    $xml->dataElement('PmtMtd', $is_coll ? 'DD' : 'TRF');
    $xml->dataElement('NbOfTxs', scalar @{ $transaction_group->{transactions} });
    $xml->dataElement('CtrlSum', $self->_format_amount($transaction_group->{sum_amount}));

    $xml->startTag('PmtTpInf');
    $xml->startTag('SvcLvl');
    $xml->dataElement('Cd', 'SEPA');
    $xml->endTag('SvcLvl');

    if ($is_coll) {
      $xml->startTag('LclInstrm');
      $xml->dataElement('Cd', 'CORE');
      $xml->endTag('LclInstrm');
      $xml->dataElement('SeqTp', 'OOFF');
    }
    $xml->endTag('PmtTpInf');

    if ($self->{version} == V3_0_0()) {
      $xml->dataElement($is_coll ? 'ReqdColltnDt' : 'ReqdExctnDt', $master_transaction->get('execution_date'));

    } elsif ($self->{version} == V3_8_0()) {
      if ($is_coll) {
        $xml->dataElement('ReqdColltnDt', $master_transaction->get('execution_date'));
      } else {
        $xml->startTag('ReqdExctnDt');
        $xml->dataElement('Dt', $master_transaction->get('execution_date'));
        $xml->endTag('ReqdExctnDt');
      }

    } else {
      die("programming error: version not handled for ReqdColl/ExctnDt");
    }

    $xml->startTag($cd_src);
    $xml->dataElement('Nm', encode('UTF-8', substr($self->{company}, 0, 70)));
    $xml->endTag($cd_src);

    $xml->startTag($cd_src . 'Acct');
    $xml->startTag('Id');
    $xml->dataElement('IBAN', $master_transaction->get('src_iban', 34));
    $xml->endTag('Id');
    $xml->endTag($cd_src . 'Acct');

    $xml->startTag($cd_src . 'Agt');
    $xml->startTag('FinInstnId');
    $xml->dataElement($bic_elt, $master_transaction->get('src_bic', 20));
    $xml->endTag('FinInstnId');
    $xml->endTag($cd_src . 'Agt');

    $xml->dataElement('ChrgBr', 'SLEV');

    if ($is_coll && ($self->{version}  == V3_8_0())) {
      $self->_emit_cdtr_scheme_id($xml);
    }

    foreach my $transaction (@{ $transaction_group->{transactions} }) {
      $xml->startTag($is_coll ? 'DrctDbtTxInf' : 'CdtTrfTxInf');

      $xml->startTag('PmtId');
      $xml->dataElement('EndToEndId', $self->_restricted_identification_sepa1($transaction->get('end_to_end_id')));
      $xml->endTag('PmtId');

      if ($is_coll) {
        $xml->startTag('InstdAmt', 'Ccy' => 'EUR');
        $xml->characters($self->_format_amount($transaction->{amount}));
        $xml->endTag('InstdAmt');

        $xml->startTag('DrctDbtTx');

        $xml->startTag('MndtRltdInf');
        $xml->dataElement('MndtId', $self->_restricted_identification_sepa2($transaction->get('mandator_id')));
        $xml->dataElement('DtOfSgntr', $self->_restricted_identification_sepa2($transaction->get('date_of_signature')));

        if ($self->{version}  == V3_0_0()) {
          $self->_emit_cdtr_scheme_id($xml);
        }

        $xml->endTag('MndtRltdInf');

        $xml->endTag('DrctDbtTx');

      } else {
        $xml->startTag('Amt');
        $xml->startTag('InstdAmt', 'Ccy' => 'EUR');
        $xml->characters($self->_format_amount($transaction->{amount}));
        $xml->endTag('InstdAmt');
        $xml->endTag('Amt');
      }

      $xml->startTag("${cd_dst}Agt");
      $xml->startTag('FinInstnId');
      $xml->dataElement($bic_elt, $transaction->get('dst_bic', 20));
      $xml->endTag('FinInstnId');
      $xml->endTag("${cd_dst}Agt");

      $xml->startTag("${cd_dst}");
      $xml->dataElement('Nm', $transaction->get('company', 70));
      $xml->endTag("${cd_dst}");

      $xml->startTag("${cd_dst}Acct");
      $xml->startTag('Id');
      $xml->dataElement('IBAN', $transaction->get('dst_iban', 34));
      $xml->endTag('Id');
      $xml->endTag("${cd_dst}Acct");

      $xml->startTag('RmtInf');
      $xml->dataElement('Ustrd', $transaction->get('reference', 140));
      $xml->endTag('RmtInf');

      $xml->endTag($is_coll ? 'DrctDbtTxInf' : 'CdtTrfTxInf');
    }

    $xml->endTag('PmtInf');
  }

  $xml->endTag($pain_elmt);
  $xml->endTag('Document');

  return $output;
}

1;

# Local Variables:
# coding: utf-8
# End:
