package SL::SEPA::XML;

use strict;
use utf8;

use Carp;
use Encode;
use List::Util qw(first sum);
use List::MoreUtils qw(any);
use POSIX qw(strftime);
use XML::Writer;

use SL::Iconv;
use SL::SEPA::XML::Transaction;

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

  map { $self->{$_} = $params{$_} if (exists $params{$_}) } qw(src_charset company message_id grouped);

  $self->{iconv} = SL::Iconv->new($self->{src_charset}, "UTF-8") || croak "Unsupported source charset $self->{src_charset}.";

  my $missing_parameter = first { !$self->{$_} } qw(company message_id);
  croak "Missing parameter: $missing_parameter" if ($missing_parameter);

  map { $self->{$_} = $self->_replace_special_chars($self->{iconv}->convert($self->{$_})) } qw(company message_id);
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
    );

  map { $text =~ s/$_/$special_chars{$_}/g; } keys %special_chars;

  return $text;
}

sub _format_amount {
  my $self   = shift;
  my $amount = shift;

  return sprintf '%d.%02d', int($amount), int($amount * 100) % 100;
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

sub to_xml {
  my $self = shift;

  croak "No transactions added yet." if (!@{ $self->{transactions} });

  my $output = '';

  my $xml    = XML::Writer->new(OUTPUT      => \$output,
                                DATA_MODE   => 1,
                                DATA_INDENT => 2,
                                ENCODING    => 'utf-8');

  my @now        = localtime;
  my $time_zone  = strftime "%z", @now;
  my $now_str    = strftime('%Y-%m-%dT%H:%M:%S', @now) . substr($time_zone, 0, 3) . ':' . substr($time_zone, 3, 2);

  my $grouped_transactions = $self->_group_transactions();

  $xml->xmlDecl();
  $xml->startTag('Document',
                 'xmlns'              => 'urn:sepade:xsd:pain.001.001.02.grp',
                 'xmlns:xsi'          => 'http://www.w3.org/2001/XMLSchema-instance',
                 'xsi:schemaLocation' => 'urn:sepade:xsd:pain.001.001.02.grp pain.001.001.02.grp.xsd');

  $xml->startTag('pain.001.001.02');

  $xml->startTag('GrpHdr');
  $xml->dataElement('MsgId', encode('UTF-8', substr($self->{message_id}, 0, 35)));
  $xml->dataElement('CreDtTm', $now_str);
  $xml->dataElement('NbOfTxs', scalar @{ $self->{transactions} });
  $xml->dataElement('CtrlSum', $self->_format_amount($grouped_transactions->{sum_amount}));
  $xml->dataElement('Grpg', 'MIXD');

  $xml->startTag('InitgPty');
  $xml->dataElement('Nm', encode('UTF-8', substr($self->{company}, 0, 70)));
  $xml->endTag('InitgPty');

  $xml->endTag('GrpHdr');

  foreach my $key (keys %{ $grouped_transactions->{groups} }) {
    my $transaction_group  = $grouped_transactions->{groups}->{$key};
    my $master_transaction = $transaction_group->{transactions}->[0];

    $xml->startTag('PmtInf');
    $xml->dataElement('PmtMtd', 'TRF');

    $xml->startTag('PmtTpInf');
    $xml->startTag('SvcLvl');
    $xml->dataElement('Cd', 'SEPA');
    $xml->endTag('SvcLvl');
    $xml->endTag('PmtTpInf');

    $xml->dataElement('ReqdExctnDt', $master_transaction->get('execution_date'));
    $xml->startTag('Dbtr');
    $xml->dataElement('Nm', encode('UTF-8', substr($self->{company}, 0, 70)));
    $xml->endTag('Dbtr');

    $xml->startTag('DbtrAcct');
    $xml->startTag('Id');
    $xml->dataElement('IBAN', $master_transaction->get('src_iban', 34));
    $xml->endTag('Id');
    $xml->endTag('DbtrAcct');

    $xml->startTag('DbtrAgt');
    $xml->startTag('FinInstnId');
    $xml->dataElement('BIC', $master_transaction->get('src_bic', 20));
    $xml->endTag('FinInstnId');
    $xml->endTag('DbtrAgt');

    $xml->dataElement('ChrgBr', 'SLEV');

    foreach my $transaction (@{ $transaction_group->{transactions} }) {
      $xml->startTag('CdtTrfTxInf');

      $xml->startTag('PmtId');
      $xml->dataElement('EndToEndId', $transaction->get('end_to_end_id', 35));
      $xml->endTag('PmtId');

      $xml->startTag('Amt');
      $xml->startTag('InstdAmt', 'Ccy' => 'EUR');
      $xml->characters($self->_format_amount($transaction->{amount}));
      $xml->endTag('InstdAmt');
      $xml->endTag('Amt');

      $xml->startTag('CdtrAgt');
      $xml->startTag('FinInstnId');
      $xml->dataElement('BIC', $transaction->get('dst_bic', 20));
      $xml->endTag('FinInstnId');
      $xml->endTag('CdtrAgt');

      $xml->startTag('Cdtr');
      $xml->dataElement('Nm', $transaction->get('recipient', 70));
      $xml->endTag('Cdtr');

      $xml->startTag('CdtrAcct');
      $xml->startTag('Id');
      $xml->dataElement('IBAN', $transaction->get('dst_iban', 34));
      $xml->endTag('Id');
      $xml->endTag('CdtrAcct');

      $xml->startTag('RmtInf');
      $xml->dataElement('Ustrd', $transaction->get('reference', 140));
      $xml->endTag('RmtInf');

      $xml->endTag('CdtTrfTxInf');
    }

    $xml->endTag('PmtInf');
  }

  $xml->endTag('pain.001.001.02');
  $xml->endTag('Document');

  return $output;
}

1;

# Local Variables:
# coding: utf-8
# End:
