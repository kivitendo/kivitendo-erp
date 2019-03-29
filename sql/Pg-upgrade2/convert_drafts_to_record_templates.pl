# @tag: convert_drafts_to_record_templates
# @description: Umwandlung von existierenden Entwürfen in Buchungsvorlagen für die Finanzbuchhaltung
# @depends: create_record_template_tables
package SL::DBUpgrade2::convert_drafts_to_record_templates;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;
use SL::YAML;

sub prepare_statements {
  my ($self) = @_;

  $self->{q_draft} = qq|
    SELECT description, form, employee_id
    FROM drafts
    WHERE module = ?
|;

  $self->{q_template} = qq|
    INSERT INTO record_templates (
      template_name, template_type,  customer_id,    vendor_id,
      currency_id,   department_id,  project_id,     employee_id,
      taxincluded,   direct_debit,   ob_transaction, cb_transaction,
      reference,     description,    ordnumber,      notes,
      ar_ap_chart_id
    ) VALUES (
      ?, ? ,?, ?,
      ?, ? ,?, ?,
      ?, ? ,?, ?,
      ?, ? ,?, ?,
      ?
    )
    RETURNING id
|;

  $self->{q_item} = qq|
    INSERT INTO record_template_items (
      record_template_id,
      chart_id, tax_id,  project_id,
      amount1,  amount2, source, memo
    ) VALUES (
      ?,
      ?, ?, ?,
      ?, ?, ?, ?
    )
|;

  $self->{h_draft}    = $self->dbh->prepare($self->{q_draft})    || die;
  $self->{h_template} = $self->dbh->prepare($self->{q_template}) || die;
  $self->{h_item}     = $self->dbh->prepare($self->{q_item})     || die;
}

sub fetch_auxilliary_data {
  my ($self) = @_;

  $self->{default_currency_id}  = selectfirst_hashref_query($::form, $self->dbh, qq|SELECT currency_id FROM defaults|)->{currency_id};
  $self->{chart_ids_by_accno}   = { selectall_as_map($::form, $self->dbh, qq|SELECT id, accno FROM chart|,      'accno', 'id') };
  $self->{currency_ids_by_name} = { selectall_as_map($::form, $self->dbh, qq|SELECT id, name  FROM currencies|, 'name',  'id') };
}

sub finish_statements {
  my ($self) = @_;

  $self->{h_item}->finish;
  $self->{h_template}->finish;
  $self->{h_draft}->finish;
}

sub migrate_ar_drafts {
  my ($self) = @_;

  $self->{h_draft}->execute('ar') || die $self->{h_draft}->errstr;

  while (my $draft_record = $self->{h_draft}->fetchrow_hashref) {
    my $draft       = SL::YAML::Load($draft_record->{form});
    my $currency_id = $self->{currency_ids_by_name}->{$draft->{currency}};
    my $employee_id = $draft_record->{employee_id} || $draft->{employee_id} || (split m{--}, $draft->{employee})[1] || undef;

    next unless $currency_id;

    my @values = (
      # template_name, template_type, customer_id, vendor_id,
      $draft_record->{description} // $::locale->text('unnamed record template'),
      'ar_transaction',
      $draft->{customer_id} || undef,
      undef,

      # currency_id, department_id, project_id, employee_id,
      $currency_id,
      $draft->{department_id}    || undef,
      $draft->{globalproject_id} || undef,
      $employee_id,

      # taxincluded,   direct_debit, ob_transaction, cb_transaction,
      $draft->{taxincluded}  ? 1 : 0,
      $draft->{direct_debit} ? 1 : 0,
      0,
      0,

      # reference, description, ordnumber, notes,
      undef,
      undef,
      $draft->{ordnumber},
      $draft->{notes},

      # ar_ap_chart_id
      $self->{chart_ids_by_accno}->{$draft->{ARselected}},
    );

    $self->{h_template}->execute(@values) || die $self->{h_template}->errstr;
    my ($template_id) = $self->{h_template}->fetchrow_array;

    foreach my $row (1..$draft->{rowcount}) {
      my ($chart_accno) = split m{--}, $draft->{"AR_amount_${row}"};
      my ($tax_id)      = split m{--}, $draft->{"taxchart_${row}"};
      my $chart_id      = $self->{chart_ids_by_accno}->{$chart_accno // ''};
      my $amount        = $::form->parse_amount($self->{format}, $draft->{"amount_${row}"});

      # $tax_id may be 0 as there's an entry in tax with id = 0.
      # $chart_id must not be 0 as there's no entry in chart with id = 0.
      next unless $chart_id && (($tax_id // '') ne '');

      @values = (
        # record_template_id,
        $template_id,

        # chart_id, tax_id, project_id,
        $chart_id,
        $tax_id,
        $draft->{"project_id_${row}"} || undef,

        # amount1, amount2, source, memo
        $amount,
        undef,
        undef,
        undef,
      );

      $self->{h_item}->execute(@values) || die $self->{h_item}->errstr;
    }
  }
}

sub migrate_ap_drafts {
  my ($self) = @_;

  $self->{h_draft}->execute('ap') || die $self->{h_draft}->errstr;

  while (my $draft_record = $self->{h_draft}->fetchrow_hashref) {
    my $draft       = SL::YAML::Load($draft_record->{form});
    my $currency_id = $self->{currency_ids_by_name}->{$draft->{currency}};
    my $employee_id = $draft_record->{employee_id} || $draft->{employee_id} || (split m{--}, $draft->{employee})[1] || undef;

    next unless $currency_id;

    my @values = (
      # template_name, template_type, customer_id, vendor_id,
      $draft_record->{description} // $::locale->text('unnamed record template'),
      'ap_transaction',
      undef,
      $draft->{vendor_id} || undef,

      # currency_id, department_id, project_id, employee_id,
      $currency_id,
      $draft->{department_id}    || undef,
      $draft->{globalproject_id} || undef,
      $employee_id,

      # taxincluded,   direct_debit, ob_transaction, cb_transaction,
      $draft->{taxincluded}   ? 1 : 0,
      $draft->{direct_credit} ? 1 : 0,
      0,
      0,

      # reference, description, ordnumber, notes,
      undef,
      undef,
      $draft->{ordnumber},
      $draft->{notes},

      # ar_ap_chart_id
      $self->{chart_ids_by_accno}->{$draft->{APselected}},
    );

    $self->{h_template}->execute(@values) || die $self->{h_template}->errstr;
    my ($template_id) = $self->{h_template}->fetchrow_array;

    foreach my $row (1..$draft->{rowcount}) {
      my ($chart_accno) = split m{--}, $draft->{"AP_amount_${row}"};
      my ($tax_id)      = split m{--}, $draft->{"taxchart_${row}"};
      my $chart_id      = $self->{chart_ids_by_accno}->{$chart_accno // ''};
      my $amount        = $::form->parse_amount($self->{format}, $draft->{"amount_${row}"});

      # $tax_id may be 0 as there's an entry in tax with id = 0.
      # $chart_id must not be 0 as there's no entry in chart with id = 0.
      next unless $chart_id && (($tax_id // '') ne '');

      @values = (
        # record_template_id,
        $template_id,

        # chart_id, tax_id, project_id,
        $chart_id,
        $tax_id,
        $draft->{"project_id_${row}"} || undef,

        # amount1, amount2, source, memo
        $amount,
        undef,
        undef,
        undef,
      );

      $self->{h_item}->execute(@values) || die $self->{h_item}->errstr;
    }
  }
}

sub migrate_gl_drafts {
  my ($self) = @_;

  $self->{h_draft}->execute('gl') || die $self->{h_draft}->errstr;

  while (my $draft_record = $self->{h_draft}->fetchrow_hashref) {
    my $draft       = SL::YAML::Load($draft_record->{form});
    my $employee_id = $draft_record->{employee_id} || $draft->{employee_id} || (split m{--}, $draft->{employee})[1] || undef;

    my @values = (
      # template_name, template_type, customer_id, vendor_id,
      $draft_record->{description} // $::locale->text('unnamed record template'),
      'gl_transaction',
      undef,
      undef,

      # currency_id, department_id, project_id, employee_id,
      $self->{default_currency_id},
      $draft->{department_id} || undef,
      undef,
      $employee_id,

      # taxincluded,   direct_debit, ob_transaction, cb_transaction,
      $draft->{taxincluded}    ? 1 : 0,
      0,
      $draft->{ob_transaction} ? 1 : 0,
      $draft->{cb_transaction} ? 1 : 0,

      # reference, description, ordnumber, notes,
      $draft->{reference},
      $draft->{description},
      undef,
      undef,

      # ar_ap_chart_id
      undef,
    );

    $self->{h_template}->execute(@values) || die $self->{h_template}->errstr;
    my ($template_id) = $self->{h_template}->fetchrow_array;

    foreach my $row (1..$draft->{rowcount}) {
      my ($chart_accno) = split m{--}, $draft->{"accno_${row}"};
      my ($tax_id)      = split m{--}, $draft->{"taxchart_${row}"};
      my $chart_id      = $self->{chart_ids_by_accno}->{$chart_accno // ''};
      my $debit         = $::form->parse_amount($self->{format}, $draft->{"debit_${row}"});
      my $credit        = $::form->parse_amount($self->{format}, $draft->{"credit_${row}"});

      # $tax_id may be 0 as there's an entry in tax with id = 0.
      # $chart_id must not be 0 as there's no entry in chart with id = 0.
      next unless $chart_id && (($tax_id // '') ne '');

      @values = (
        # record_template_id,
        $template_id,

        # chart_id, tax_id, project_id,
        $chart_id,
        $tax_id,
        $draft->{"project_id_${row}"} || undef,

        # amount1, amount2, source, memo
        $debit,
        $credit,
        $draft->{"source_${row}"},
        $draft->{"memo_${row}"},
      );

      $self->{h_item}->execute(@values) || die $self->{h_item}->errstr;
    }
  }
}

sub clean_drafts {
  my ($self) = @_;

  $self->db_query(qq|DELETE FROM drafts WHERE module IN ('ar', 'ap', 'gl')|);
}

sub run {
  my ($self) = @_;

  # A dummy for %::myconfig used for parsing numbers. The existing
  # drafts have a fundamental flaw: they store numbers & dates in the
  # database still formatted to the user's preferences. Determining
  # the correct format is not possible. Therefore this script simply
  # assumes that the installation is used by people with German
  # preferences regarding both settings.
  $self->{format} = {
    numberformat => '1000,00',
    dateformat   => 'dd.mm.yy',
  };

  $self->prepare_statements;
  $self->fetch_auxilliary_data;
  $self->migrate_ar_drafts;
  $self->migrate_ap_drafts;
  $self->migrate_gl_drafts;
  $self->clean_drafts;
  $self->finish_statements;

  return 1;
}

1;
