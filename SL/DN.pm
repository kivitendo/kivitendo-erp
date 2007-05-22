#======================================================================
# LX-Office ERP
# Copyright (C) 2006
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 1998-2002
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
#  Contributors:
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#======================================================================
#
# Dunning process module
#
#======================================================================

package DN;

use SL::Template;
use SL::IS;
use SL::Common;
use SL::DBUtils;
use Data::Dumper;

sub get_config {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query =
    qq|SELECT * | .
    qq|FROM dunning_config | .
    qq|ORDER BY dunning_level|;
  $form->{DUNNING} = selectall_hashref_query($form, $dbh, $query);

  foreach my $ref (@{ $form->{DUNNING} }) {
    $ref->{fee} = $form->format_amount($myconfig, $ref->{fee}, 2);
    $ref->{interest_rate} = $form->format_amount($myconfig, ($ref->{interest_rate} * 100));
  }

  $dbh->disconnect();

  $main::lxdebug->leave_sub();
}

sub save_config {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my ($query, @values);

  for my $i (1 .. $form->{rowcount}) {
    $form->{"fee_$i"} = $form->parse_amount($myconfig, $form->{"fee_$i"}) * 1;
    $form->{"interest_rate_$i"} = $form->parse_amount($myconfig, $form->{"interest_rate_$i"}) / 100;

    if (($form->{"dunning_level_$i"} ne "") &&
        ($form->{"dunning_description_$i"} ne "")) {
      @values = (conv_i($form->{"dunning_level_$i"}), $form->{"dunning_description_$i"},
                 $form->{"email_subject_$i"}, $form->{"email_body_$i"},
                 $form->{"template_$i"}, $form->{"fee_$i"}, $form->{"interest_rate_$i"},
                 $form->{"active_$i"} ? 't' : 'f', $form->{"auto_$i"} ? 't' : 'f', $form->{"email_$i"} ? 't' : 'f',
                 $form->{"email_attachment_$i"} ? 't' : 'f', conv_i($form->{"payment_terms_$i"}), conv_i($form->{"terms_$i"}));
      if ($form->{"id_$i"}) {
        $query =
          qq|UPDATE dunning_config SET
               dunning_level = ?, dunning_description = ?,
               email_subject = ?, email_body = ?,
               template = ?, fee = ?, interest_rate = ?,
               active = ?, auto = ?, email = ?,
               email_attachment = ?, payment_terms = ?, terms = ?
             WHERE id = ?|;
        push(@values, conv_i($form->{"id_$i"}));
      } else {
        $query =
          qq|INSERT INTO dunning_config
               (dunning_level, dunning_description, email_subject, email_body,
                template, fee, interest_rate, active, auto, email,
                email_attachment, payment_terms, terms)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)|;
      }
      do_query($form, $dbh, $query, @values);
    }

    if (($form->{"dunning_description_$i"} eq "") && ($form->{"id_$i"})) {
      $query = qq|DELETE FROM dunning_config WHERE id = ?|;
      do_query($form, $dbh, $query, $form->{"id_$i"});
    }
  }

  $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub save_dunning {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $rows, $userspath, $spool, $sendmail) = @_;
  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my ($query, @values);

  my ($dunning_id) = selectrow_query($form, $dbh, qq|SELECT nextval('id')|);

  my $q_update_ar = qq|UPDATE ar SET dunning_config_id = ? WHERE id = ?|;
  my $h_update_ar = prepare_query($form, $dbh, $q_update_ar);

  my $q_insert_dunning =
    qq|INSERT INTO dunning (dunning_id, dunning_config_id, dunning_level,
                            trans_id, fee, interest, transdate, duedate)
       VALUES (?, ?,
               (SELECT dunning_level FROM dunning_config WHERE id = ?),
               ?,
               (SELECT SUM(fee)
                FROM dunning_config
                WHERE dunning_level <= (SELECT dunning_level FROM dunning_config WHERE id = ?)),
               (SELECT (amount - paid) * (current_date - transdate) FROM ar WHERE id = ?)
                 * (SELECT interest_rate FROM dunning_config WHERE id = ?)
                 / 360,
               current_date,
               current_date + (SELECT payment_terms FROM dunning_config WHERE id = ?))|;
  my $h_insert_dunning = prepare_query($form, $dbh, $q_insert_dunning);

  my @invoice_ids;
  my ($next_dunning_config_id, $customer_id);
  my $send_email = 0;

  foreach my $row (@{ $rows }) {
    push @invoice_ids, $row->{invoice_id};
    $next_dunning_config_id = $row->{next_dunning_config_id};
    $customer_id            = $row->{customer_id};

    @values = ($row->{next_dunning_config_id}, $row->{invoice_id});
    do_statement($form, $h_update_ar, $q_update_ar, @values);

    $send_email |= $row->{email};

    my $next_config_id = conv_i($row->{next_dunning_config_id});
    my $invoice_id     = conv_i($row->{invoice_id});

    @values = ($dunning_id,     $next_config_id, $next_config_id,
               $invoice_id,     $next_config_id, $invoice_id,
               $next_config_id, $next_config_id);
    do_statement($form, $h_insert_dunning, $q_insert_dunning, @values);
  }

  $h_update_ar->finish();
  $h_insert_dunning->finish();

  my $query =
    qq|SELECT
         ar.invnumber, ar.ordnumber, ar.amount, ar.netamount,
         ar.transdate, ar.duedate, ar.paid, ar.amount - ar.paid AS open_amount,
         da.fee, da.interest, da.transdate AS dunning_date, da.duedate AS dunning_duedate
       FROM ar
       LEFT JOIN dunning_config cfg ON (cfg.id = ar.dunning_config_id)
       LEFT JOIN dunning da ON (ar.id = da.trans_id AND cfg.dunning_level = da.dunning_level)
       WHERE ar.id IN (|
       . join(", ", map { "?" } @invoice_ids) . qq|)|;

  my $sth = prepare_execute_query($form, $dbh, $query, @invoice_ids);
  my $first = 1;
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    if ($first) {
      map({ $form->{"dn_$_"} = []; } keys(%{$ref}));
      $first = 0;
    }

    $ref->{interest_rate} = $form->format_amount($myconfig, $ref->{interest_rate} * 100);
    map { $ref->{$_} = $form->format_amount($myconfig, $ref->{$_}, 2) } qw(amount netamount paid open_amount fee interest);
    map { push(@{ $form->{"dn_$_"} }, $ref->{$_})} keys %$ref;
    map { $form->{$_} = $ref->{$_} } keys %{ $ref };
  }
  $sth->finish;

  $query =
    qq|SELECT id AS customer_id, name, street, zipcode, city, country, department_1, department_2, email
       FROM customer
       WHERE id = ?|;
  $ref = selectfirst_hashref_query($form, $dbh, $query, $customer_id);
  map { $form->{$_} = $ref->{$_} } keys %{ $ref };

  $query =
    qq|SELECT
         cfg.interest_rate, cfg.template AS formname,
         cfg.email_subject, cfg.email_body, cfg.email_attachment,
         (SELECT SUM(fee)
          FROM dunning
          WHERE dunning_id = ?)
         AS fee,
         (SELECT SUM(interest)
          FROM dunning
          WHERE dunning_id = ?)
         AS total_interest,
         (SELECT SUM(amount) - SUM(paid)
          FROM ar
          WHERE id IN (| . join(", ", map { "?" } @invoice_ids) . qq|))
         AS total_open_amount
       FROM dunning_config cfg
       WHERE id = ?|;
  $ref = selectfirst_hashref_query($form, $dbh, $query, $dunning_id, $dunning_id, @invoice_ids, $next_dunning_config_id);
  map { $form->{$_} = $ref->{$_} } keys %{ $ref };

  $form->{interest_rate}     = $form->format_amount($myconfig, $ref->{interest_rate} * 100);
  $form->{fee}               = $form->format_amount($myconfig, $ref->{fee}, 2);
  $form->{total_interest}    = $form->format_amount($myconfig, $form->round_amount($ref->{total_interest}, 2), 2);
  $form->{total_open_amount} = $form->format_amount($myconfig, $form->round_amount($ref->{total_open_amount}, 2), 2);
  $form->{total_amount}      = $form->format_amount($myconfig, $form->round_amount($ref->{fee} + $ref->{total_interest} + $ref->{total_open_amount}, 2), 2);

  $form->{templates}    = "$myconfig->{templates}";
  $form->{language}     = $form->get_template_language(\%myconfig);
  $form->{printer_code} = $form->get_printer_code(\%myconfig);

  if ($form->{language} ne "") {
    $form->{language} = "_" . $form->{language};
  }

  if ($form->{printer_code} ne "") {
    $form->{printer_code} = "_" . $form->{printer_code};
  }

  $form->{IN} = "$form->{formname}$form->{language}$form->{printer_code}.html";
  if ($form->{format} eq 'postscript') {
    $form->{postscript} = 1;
    $form->{IN} =~ s/html$/tex/;
  } elsif ($form->{"format"} =~ /pdf/) {
    $form->{pdf} = 1;
    if ($form->{"format"} =~ /opendocument/) {
      $form->{IN} =~ s/html$/odt/;
    } else {
      $form->{IN} =~ s/html$/tex/;
    }
  } elsif ($form->{"format"} =~ /opendocument/) {
    $form->{"opendocument"} = 1;
    $form->{"IN"} =~ s/html$/odt/;
  }

  if ($send_email && ($form->{email} ne "")) {
    $form->{media} = 'email';
  }

  $form->{keep_tmpfile} = 0;
  if ($form->{media} eq 'email') {
    $form->{subject} = qq|$form->{label} $form->{"${inv}number"}|
      unless $form->{subject};
    if (!$form->{email_attachment}) {
      $form->{do_not_attach} = 1;
    } else {
      $form->{do_not_attach} = 0;
    }
    $form->{subject} = parse_strings($myconfig, $form, $userspath, $form->{email_subject});
    $form->{message} = parse_strings($myconfig, $form, $userspath, $form->{email_body});

    $form->{OUT} = "$sendmail";

  } else {

    my $filename = Common::unique_id() . $form->{login} . ".pdf";
    $form->{OUT} = ">$spool/$filename";
    push(@{ $form->{DUNNING_PDFS} }, $filename);
    $form->{keep_tmpfile} = 1;
  }

  delete($form->{tmpfile});
  $form->parse_template($myconfig, $userspath);

  $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_invoices {

  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $where;
  my @values;

  $form->{customer_id} = $1 if ($form->{customer} =~ /--(\d+)$/);

  if ($form->{customer_id}) {
    $where .= qq| AND (a.customer_id = ?)|;
    push(@values, $form->{customer_id});

  } elsif ($form->{customer}) {
    $where .= qq| AND (ct.name ILIKE ?)|;
    push(@values, '%' . $form->{customer} . '%');
  }

  my %columns = (
    "ordnumber" => "a.ordnumber",
    "invnumber" => "a.invnumber",
    "notes"     => "a.notes",
    );
  foreach my $key (keys(%columns)) {
    next unless ($form->{$key});
    $where .= qq| AND $columns{$key} ILIKE ?|;
    push(@values, '%' . $form->{$key} . '%');
  }

  if ($form->{dunning_level}) {
    $where .= qq| AND nextcfg.id = ?|;
    push(@values, conv_i($form->{dunning_level}));
  }

  $form->{minamount} = $form->parse_amount($myconfig,$form->{minamount});
  if ($form->{minamount}) {
    $where .= qq| AND ((a.amount - a.paid) > ?) |;
    push(@values, $form->{minamount});
  }

  $query =
    qq|SELECT
         a.id, a.ordnumber, a.transdate, a.invnumber, a.amount,
         ct.name AS customername, a.customer_id, a.duedate,

         cfg.dunning_description, cfg.dunning_level,

         d.transdate AS dunning_date, d.duedate AS dunning_duedate,
         d.fee, d.interest,

         a.duedate + cfg.terms - current_date AS nextlevel,
         current_date - COALESCE(d.duedate, a.duedate) AS pastdue,
         current_date + cfg.payment_terms AS next_duedate,

         nextcfg.dunning_description AS next_dunning_description,
         nextcfg.id AS next_dunning_config_id,
         nextcfg.terms, nextcfg.active, nextcfg.email

       FROM ar a

       LEFT JOIN customer ct ON (a.customer_id = ct.id)
       LEFT JOIN dunning_config cfg ON (a.dunning_config_id = cfg.id)
       LEFT JOIN dunning_config nextcfg ON
         (nextcfg.id =
           (SELECT id
            FROM dunning_config
            WHERE dunning_level >
              COALESCE((SELECT dunning_level
                        FROM dunning_config
                        WHERE id = a.dunning_config_id
                        ORDER BY dunning_level DESC
                        LIMIT 1),
                       0)
            LIMIT 1))
       LEFT JOIN dunning d ON ((d.trans_id = a.id) AND (cfg.dunning_level = d.dunning_level))

       WHERE (a.paid < a.amount)
         AND (a.duedate < current_date)

       $where

       ORDER BY a.id, transdate, duedate, name|;
  my $sth = prepare_execute_query($form, $dbh, $query, @values);

  $form->{DUNNINGS} = [];

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    next if !$ref->{terms} || ($ref->{pastdue} < $ref->{terms});

    $ref->{interest} = $form->round_amount($ref->{interest}, 2);
    push(@{ $form->{DUNNINGS} }, $ref);
  }

  $sth->finish;

  $query = qq|SELECT id, dunning_description FROM dunning_config ORDER BY dunning_level|;
  $form->{DUNNING_CONFIG} = selectall_hashref_query($form, $dbh, $query);

  $dbh->disconnect;
  $main::lxdebug->leave_sub();
}

sub get_dunning {

  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $where = qq| WHERE (da.trans_id = a.id)|;

  my @values;

  if ($form->{customer_id}) {
    $where .= qq| AND (a.customer_id = ?)|;
    push(@values, $form->{customer_id});

  } elsif ($form->{customer}) {
    $where .= qq| AND (ct.name ILIKE ?)|;
    push(@values, '%' . $form->{customer} . '%');
  }

  my %columns = (
    "ordnumber" => "a.ordnumber",
    "invnumber" => "a.invnumber",
    "notes" => "a.notes",
    );
  foreach my $key (keys(%columns)) {
    next unless ($form->{$key});
    $where .= qq| AND $columns{$key} ILIKE ?|;
    push(@values, '%' . $form->{$key} . '%');
  }

  if ($form->{dunning_level}) {
    $where .= qq| AND a.dunning_config_id = ?|;
    push(@values, conv_i($form->{dunning_level}));
  }

  if ($form->{department_id}) {
    $where .= qq| AND a.department_id = ?|;
    push @values, conv_i($form->{department_id});
  }

  $form->{minamount} = $form->parse_amount($myconfig, $form->{minamount});
  if ($form->{minamount}) {
    $where .= qq| AND ((a.amount - a.paid) > ?) |;
    push(@values, $form->{minamount});
  }

  if (!$form->{showold}) {
    $where .= qq| AND (a.amount > a.paid) AND (da.dunning_config_id = a.dunning_config_id) |;
  }

  if ($form->{transdatefrom}) {
    $where .= qq| AND a.transdate >= ?|;
    push(@values, $form->{transdatefrom});
  }
  if ($form->{transdateto}) {
    $where .= qq| AND a.transdate <= ?|;
    push(@values, $form->{transdateto});
  }
  if ($form->{dunningfrom}) {
    $where .= qq| AND da.transdate >= ?|;
    push(@values, $form->{dunningfrom});
  }
  if ($form->{dunningto}) {
    $where .= qq| AND da.transdate >= ?|;
    push(@values, $form->{dunningto});
  }

  $query =
    qq|SELECT a.id, a.ordnumber, a.invoice, a.transdate, a.invnumber, a.amount,
         ct.name AS customername, ct.id AS customer_id, a.duedate, da.fee,
         da.interest, dn.dunning_description, da.transdate AS dunning_date,
         da.duedate AS dunning_duedate, da.dunning_id, da.dunning_config_id
       FROM ar a
       JOIN customer ct ON (a.customer_id = ct.id), dunning da
       LEFT JOIN dunning_config dn ON (da.dunning_config_id = dn.id)
       $where
       ORDER BY name, a.id|;

  $form->{DUNNINGS} = selectall_hashref_query($form, $dbh, $query, @values);

  foreach my $ref (@{ $form->{DUNNINGS} }) {
    map { $ref->{$_} = $form->format_amount($myconfig, $ref->{$_}, 2)} qw(amount fee interest);
  }

  $dbh->disconnect;
  $main::lxdebug->leave_sub();
}

sub parse_strings {

  $main::lxdebug->enter_sub();

  my ($myconfig, $form, $userspath, $string) = @_;

  local (*IN, *OUT);

  my $format = $form->{format};
  $form->{format} = "html";

  $tmpstring = "parse_string.html";
  $tmpfile = "$myconfig->{templates}/$tmpstring";
  open(OUT, ">", $tmpfile) or $form->error("$tmpfile : $!");

  print(OUT $string);
  close(OUT);

  my $in = $form->{IN};
  $form->{IN} = $tmpstring;
  $template = HTMLTemplate->new($tmpstring, $form, $myconfig, $userspath);

  my $fileid = time;
  $form->{tmpfile} = "$userspath/${fileid}.$tmpstring";

  open(OUT, ">", $form->{tmpfile}) or $form->error("$form->{OUT} : $!");
  if (!$template->parse(*OUT)) {
    $form->cleanup();
    $form->error("$form->{IN} : " . $template->get_error());
  }

  close(OUT);
  my $result = "";
  open(IN, "<", $form->{tmpfile}) or $form->error($form->cleanup . "$form->{tmpfile} : $!");

  while (<IN>) {
    $result .= $_;
  }

  close(IN);
#   unlink($tmpfile);
#   unlink($form->{tmpfile});
  $form->{IN} = $in;
  $form->{format} = $format;

  $main::lxdebug->leave_sub();
  return $result;
}

sub melt_pdfs {

  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $userspath) = @_;

  local (*IN, *OUT);

  # Don't allow access outside of $userspath.
  map { $_ =~ s|.*/||; } @{ $form->{DUNNING_PDFS} };

  my $inputfiles = join " ", map { "$userspath/$_" } @{ $form->{DUNNING_PDFS} };
  my $outputfile = "$userspath/dunning.pdf";

  system("gs -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -sOutputFile=$outputfile $inputfiles");

  map { unlink("$userspath/$_") } @{ $form->{DUNNING_PDFS} };

  my $numbytes = (-s $outputfile);
  open(IN, $outputfile) || $form->error($self->cleanup() . "$outputfile : $!");

  $form->{copies} = 1 unless $form->{media} eq 'printer';

  chdir($self->{cwd});

  for my $i (1 .. $form->{copies}) {
    # launch application
    print qq|Content-Type: Application/PDF
Content-Disposition: attachment; filename="$outputfile"
Content-Length: $numbytes

|;

    open(OUT, ">-") or $form->error($form->cleanup . "$!: STDOUT");

    while (<IN>) {
      print OUT $_;
    }

    close(OUT);

    seek(IN, 0, 0);
  }

  close(IN);
  unlink($outputfile);

  $main::lxdebug->leave_sub();
}

sub print_dunning {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $dunning_id, $userspath, $spool, $sendmail) = @_;
  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query =
    qq|SELECT invnumber, ordnumber, customer_id, amount, netamount,
         ar.transdate, ar.duedate, paid, amount - paid AS open_amount,
         template AS formname, email_subject, email_body, email_attachment,
         da.fee, da.interest, da.transdate AS dunning_date, da.duedate AS dunning_duedate
       FROM dunning da
       LEFT JOIN dunning_config ON (dunning_config.id = da.dunning_config_id)
       LEFT JOIN ar ON (ar.id = da.trans_id)
       WHERE (da.dunning_id = ?)|;

  my $sth = prepare_execute_query($form, $dbh, $query, $dunning_id);
  my $first = 1;
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    if ($first) {
      map({ $form->{"dn_$_"} = []; } keys(%{$ref}));
      $first = 0;
    }
    map { $ref->{$_} = $form->format_amount($myconfig, $ref->{$_}, 2) } qw(amount netamount paid open_amount fee interest);
    map { $form->{$_} = $ref->{$_} } keys %$ref;
    map { push @{ $form->{"dn_$_"} }, $ref->{$_}} keys %$ref;
  }
  $sth->finish;

  $query =
    qq|SELECT id AS customer_id, name, street, zipcode, city, country, department_1, department_2, email
       FROM customer
       WHERE id =
         (SELECT customer_id
          FROM dunning d
          LEFT JOIN ar ON (d.trans_id = ar.id)
          WHERE d.id = ?)|;
  $ref = selectfirst_hashref_query($form, $dbh, $query, $dunning_id);
  map { $form->{$_} = $ref->{$_} } keys %{ $ref };

  $query =
    qq|SELECT
         cfg.interest_rate, cfg.template AS formname,
         cfg.email_subject, cfg.email_body, cfg.email_attachment,
         d.transdate AS dunning_date,
         (SELECT SUM(fee)
          FROM dunning
          WHERE dunning_id = ?)
         AS fee,
         (SELECT SUM(interest)
          FROM dunning
          WHERE dunning_id = ?)
         AS total_interest,
         (SELECT SUM(amount) - SUM(paid)
          FROM ar
          WHERE id IN
            (SELECT trans_id
             FROM dunning
             WHERE dunning_id = ?))
         AS total_open_amount
       FROM dunning d
       LEFT JOIN dunning_config cfg ON (d.dunning_config_id = cfg.id)
       WHERE d.dunning_id = ?
       LIMIT 1|;
  $ref = selectfirst_hashref_query($form, $dbh, $query, $dunning_id, $dunning_id, $dunning_id, $dunning_id);
  map { $form->{$_} = $ref->{$_} } keys %{ $ref };

  $form->{interest_rate}     = $form->format_amount($myconfig, $ref->{interest_rate} * 100);
  $form->{fee}               = $form->format_amount($myconfig, $ref->{fee}, 2);
  $form->{total_interest}    = $form->format_amount($myconfig, $form->round_amount($ref->{total_interest}, 2), 2);
  $form->{total_open_amount} = $form->format_amount($myconfig, $form->round_amount($ref->{total_open_amount}, 2), 2);
  $form->{total_amount}      = $form->format_amount($myconfig, $form->round_amount($ref->{fee} + $ref->{total_interest} + $ref->{total_open_amount}, 2), 2);


  $form->{templates} = "$myconfig->{templates}";

  $form->{language} = $form->get_template_language(\%myconfig);
  $form->{printer_code} = $form->get_printer_code(\%myconfig);

  if ($form->{language} ne "") {
    $form->{language} = "_" . $form->{language};
  }

  if ($form->{printer_code} ne "") {
    $form->{printer_code} = "_" . $form->{printer_code};
  }

  $form->{IN} = "$form->{formname}$form->{language}$form->{printer_code}.html";
  if ($form->{format} eq 'postscript') {
    $form->{postscript} = 1;
    $form->{IN} =~ s/html$/tex/;
  } elsif ($form->{"format"} =~ /pdf/) {
    $form->{pdf} = 1;
    if ($form->{"format"} =~ /opendocument/) {
      $form->{IN} =~ s/html$/odt/;
    } else {
      $form->{IN} =~ s/html$/tex/;
    }
  } elsif ($form->{"format"} =~ /opendocument/) {
    $form->{"opendocument"} = 1;
    $form->{"IN"} =~ s/html$/odt/;
  }

  if ($form->{"send_email"} && ($form->{email} ne "")) {
    $form->{media} = 'email';
  }

  $form->{keep_tmpfile} = 0;
  if ($form->{media} eq 'email') {
    $form->{subject} = qq|$form->{label} $form->{"${inv}number"}|
      unless $form->{subject};
    if (!$form->{email_attachment}) {
      $form->{do_not_attach} = 1;
    } else {
      $form->{do_not_attach} = 0;
    }
    $form->{subject} = parse_strings($myconfig, $form, $userspath, $form->{email_subject});
    $form->{message} = parse_strings($myconfig, $form, $userspath, $form->{email_body});

    $form->{OUT} = "$sendmail";

  } else {

    my $filename = Common::unique_id() . $form->{login} . ".pdf";

    push(@{ $form->{DUNNING_PDFS} }, $filename);
    $form->{keep_tmpfile} = 1;
  }

  $form->parse_template($myconfig, $userspath);

  $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

1;
