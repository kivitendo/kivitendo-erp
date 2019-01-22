package Taxkeys;

use Memoize;

use SL::DBUtils;

use strict;

sub new {
  my $type = shift;

  my $self = {};

  bless $self, $type;

  return $self->_init();
}

sub DESTROY {
  my $self = shift;

  $self->_finish_statements();
}

sub _init {
  my $self = shift;

  $self->{handles} = { };
  $self->{queries} = { };

  memoize 'get_tax_info';
  memoize 'get_full_tax_info';

  return $self;
}

sub _finish_statements {
  $main::lxdebug->enter_sub();

  my $self = shift;

  foreach my $idx (keys %{ $self->{handles} }) {
    $self->{handles}->{$idx}->finish();
    delete $self->{handles}->{$idx};
  }

  $main::lxdebug->leave_sub();
}

sub get_tax_info {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(transdate taxkey));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  if (!$self->{handles}->{get_tax_info}) {
    $self->{queries}->{get_tax_info} = qq|
      SELECT t.rate AS taxrate, c.accno as taxnumber, t.taxdescription, t.chart_id AS taxchart_id,
        c.accno AS taxaccno, c.description AS taxaccount
      FROM taxkeys tk
      LEFT JOIN tax t   ON (tk.tax_id  = t.id)
      LEFT JOIN chart c ON (t.chart_id = c.id)
      WHERE tk.id =
        (SELECT id
         FROM taxkeys
         WHERE (taxkey_id = ?)
           AND (startdate <= ?)
         ORDER BY startdate DESC
         LIMIT 1)
|;

    $self->{handles}->{get_tax_info} = prepare_query($form, $params{dbh} || $form->get_standard_dbh($myconfig), $self->{queries}->{get_tax_info});
  }

  my $sth = $self->{handles}->{get_tax_info};
  # Lieferdatum (deliverydate) ist entscheidend für den Steuersatz
  do_statement($form, $sth, $self->{queries}->{get_tax_info}, $params{taxkey}, $params{deliverydate} || $params{transdate});

  my $ref = $sth->fetchrow_hashref() || { };

  $main::lxdebug->leave_sub();

  return $ref;
}

sub get_full_tax_info {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(transdate));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my %tax_info     = (
    'taxkeys'      => { },
    'taxchart_ids' => { },
    );

  my @all_taxkeys = map { $_->{taxkey} } (selectall_hashref_query($form, $form->get_standard_dbh(), qq|SELECT DISTINCT taxkey FROM tax WHERE taxkey IS NOT NULL|));

  foreach my $taxkey (@all_taxkeys) {
    my $ref = $self->get_tax_info('transdate' => $params{transdate}, 'taxkey' => $taxkey, 'deliverydate' => $params{deliverydate});

    $tax_info{taxkeys}->{$taxkey}            = $ref;
    $tax_info{accnos}->{$ref->{taxchart_id}} = $ref if ($ref->{taxchart_id});
  }

  $main::lxdebug->leave_sub();

  return %tax_info;
}

1;
