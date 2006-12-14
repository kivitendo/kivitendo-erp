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
use Data::Dumper;

sub get_config {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT dn.*
                 FROM dunning_config dn
		 ORDER BY dn.dunning_level|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{fee} = $form->format_amount($myconfig, $ref->{fee}, 2);
    $ref->{interest} = $form->format_amount($myconfig, ($ref->{interest} * 100));
    push @{ $form->{DUNNING} }, $ref;
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}


sub save_config {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  for my $i (1 .. $form->{rowcount}) {
    $form->{"active_$i"} *= 1; 
    $form->{"auto_$i"} *= 1; 
    $form->{"email_$i"} *= 1; 
    $form->{"terms_$i"} *= 1; 
    $form->{"payment_terms_$i"} *= 1; 
    $form->{"email_attachment_$i"} *= 1;
    $form->{"fee_$i"} = $form->parse_amount($myconfig, $form->{"fee_$i"}) * 1;
    $form->{"interest_$i"} = $form->parse_amount($myconfig, $form->{"interest_$i"})/100;
    
    if (($form->{"dunning_level_$i"} ne "") && ($form->{"dunning_description_$i"} ne "")) {
      if ($form->{"id_$i"}) {
        my $query = qq|UPDATE dunning_config SET
                       dunning_level = | . $dbh->quote($form->{"dunning_level_$i"}) . qq|,
                       dunning_description = | . $dbh->quote($form->{"dunning_description_$i"}) . qq|,
                       email_subject = | . $dbh->quote($form->{"email_subject_$i"}) . qq|,
                       email_body = | . $dbh->quote($form->{"email_body_$i"}) . qq|,
                       template = | . $dbh->quote($form->{"template_$i"}) . qq|,
                       fee = '$form->{"fee_$i"}',
                       interest = '$form->{"interest_$i"}',
                       active = '$form->{"active_$i"}',
                       auto = '$form->{"auto_$i"}',
                       email = '$form->{"email_$i"}',
                       email_attachment = '$form->{"email_attachment_$i"}',
                       payment_terms = $form->{"payment_terms_$i"},
                       terms = $form->{"terms_$i"}
		       WHERE id=$form->{"id_$i"}|;
        $dbh->do($query)  || $form->dberror($query);
      } else {
        my $query = qq|INSERT INTO dunning_config (dunning_level, dunning_description, email_subject, email_body, template, fee, interest, active, auto, email, email_attachment, terms, payment_terms) VALUES (| . $dbh->quote($form->{"dunning_level_$i"}) . qq|,| . $dbh->quote($form->{"dunning_description_$i"}) . qq|,| . $dbh->quote($form->{"email_subject_$i"}) . qq|,| . $dbh->quote($form->{"email_body_$i"}) . qq|,| . $dbh->quote($form->{"template_$i"}) . qq|,'$form->{"fee_$i"}','$form->{"interest_$i"}','$form->{"active_$i"}','$form->{"auto_$i"}','$form->{"email_$i"}','$form->{"email_attachment_$i"}',$form->{"terms_$i"},$form->{"payment_terms_$i"})|;
        $dbh->do($query)  || $form->dberror($query);
      }
    }
    if (($form->{"dunning_description_$i"} eq "") && ($form->{"id_$i"})) {
      my $query = qq|DELETE FROM dunning_config WHERE id=$form->{"id_$i"}|;
      $dbh->do($query)  || $form->dberror($query);
    }
  }

  $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub save_dunning {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $rows, $userspath,$spool, $sendmail) = @_;
  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  foreach my $row (@{ $rows }) { 
  
    $form->{"interest_$row"} = $form->parse_amount($myconfig,$form->{"interest_$row"});
    $form->{"fee_$row"} = $form->parse_amount($myconfig,$form->{"fee_$row"});
    $form->{send_email} = $form->{"email_$row"};
  
    my $query = qq| UPDATE ar set dunning_id = '$form->{"next_dunning_id_$row"}' WHERE id='$form->{"inv_id_$row"}'|;
    $dbh->do($query) || $form->dberror($query);
    my $query = qq| INSERT into dunning (dunning_id,dunning_level,trans_id,fee,interest,transdate,duedate) VALUES ($form->{"next_dunning_id_$row"},(select dunning_level from dunning_config WHERE id=$form->{"next_dunning_id_$row"}),$form->{"inv_id_$row"},'$form->{"fee_$row"}', '$form->{"interest_$row"}',current_date, |.$dbh->quote($form->{"next_duedate_$row"}) . qq|)|;
    $dbh->do($query) || $form->dberror($query);
  }

  my $query = qq| SELECT invnumber, ordnumber, customer_id, amount, netamount, ar.transdate, ar.duedate, paid, amount-paid AS open_amount, template AS formname, email_subject, email_body, email_attachment, da.fee, da.interest, da.transdate AS dunning_date, da.duedate AS dunning_duedate FROM ar LEFT JOIN dunning_config ON (dunning_config.id=ar.dunning_id) LEFT JOIN dunning da ON (ar.id=da.trans_id) where ar.id IN $form->{inv_ids}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  my $first = 1;
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    if ($first) {
      map({ $form->{"dn_$_"} = []; } keys(%{$ref}));
      $first = 0;
    }
    map { $ref->{$_} = $form->format_amount($myconfig, $ref->{$_}, 2) } qw(amount netamount paid open_amount fee interest);
    map { $form->{$_} = $ref->{$_} } keys %$ref;
    #print(STDERR Dumper($ref));
    map { push @{ $form->{"dn_$_"} }, $ref->{$_}} keys %$ref;
  }
  $sth->finish;

  IS->customer_details($myconfig,$form);
  #print(STDERR Dumper($form->{dn_invnumber}));
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
    
    my $uid = rand() . time;

    $uid .= $form->{login};

    $uid = substr($uid, 2, 75);
    $filename = $uid;

    $filename .= '.pdf';
    $form->{OUT} = ">$spool/$filename";
    push(@{ $form->{DUNNING_PDFS} }, $filename);
    $form->{keep_tmpfile} = 1;
  }
  
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

  $where = qq| WHERE 1=1 AND a.paid < a.amount AND a.duedate < current_date AND dnn.id = (select id from dunning_config WHERE dunning_level>(select case when a.dunning_id is null then 0 else (select dunning_level from dunning_config where id=a.dunning_id order by dunning_level  limit 1 ) end from dunning_config limit 1) limit 1) |;

  if ($form->{"$form->{vc}_id"}) {
    $where .= qq| AND a.$form->{vc}_id = $form->{"$form->{vc}_id"}|;
  } else {
    if ($form->{ $form->{vc} }) {
      $where .= " AND lower(ct.name) LIKE '$name'";
    }
  }

  my $sortorder = join ', ',
    ("a.id", $form->sort_columns(transdate, duedate, name));
  $sortorder = $form->{sort} if $form->{sort};

  $where .= " AND lower(ordnumber) LIKE '$form->{ordnumber}'" if $form->{ordnumber};
  $where .= " AND lower(invnumber) LIKE '$form->{invnumber}'" if $form->{invnumber};


  $form->{minamount} = $form->parse_amount($myconfig,$form->{minamount});
  $where .= " AND a.dunning_id='$form->{dunning_level}'"
    if $form->{dunning_level};
  $where .= " AND a.ordnumber ilike '%$form->{ordnumber}%'"
    if $form->{ordnumber};
  $where .= " AND a.invnumber ilike '%$form->{invnumber}%'"
    if $form->{invnumber};
  $where .= " AND a.notes ilike '%$form->{notes}%'"
    if $form->{notes};
  $where .= " AND ct.name ilike '%$form->{customer}%'"
    if $form->{customer};

  $where .= " AND a.amount-a.paid>'$form->{minamount}'"
    if $form->{minamount};

  $where .= " ORDER by $sortorder";

  $paymentdate = ($form->{paymentuntil}) ? "'$form->{paymentuntil}'" : current_date;

  $query = qq|SELECT a.id, a.ordnumber, a.transdate, a.invnumber,a.amount, ct.name AS customername, a.customer_id, a.duedate,da.fee AS old_fee, dnn.fee as fee, dn.dunning_description, da.transdate AS dunning_date, da.duedate AS dunning_duedate, a.duedate + dnn.terms - current_date AS nextlevel, $paymentdate - a.duedate AS pastdue, dn.dunning_level, current_date + dnn.payment_terms AS next_duedate, dnn.dunning_description AS next_dunning_description, dnn.id AS next_dunning_id, dnn.interest AS interest_rate, dnn.terms
	         FROM dunning_config dnn, ar a
	         JOIN customer ct ON (a.customer_id = ct.id)
		 LEFT JOIN dunning_config dn ON (dn.id = a.dunning_id)
                 LEFT JOIN dunning da ON (da.trans_id=a.id)
                 $where|;

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);


  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{fee} += $ref->{old_fee};
    $ref->{interest} = ($ref->{amount} * $ref->{pastdue} * $ref->{interest_rate}) /360;
    $ref->{interest} = $form->round_amount($ref->{interest},2);
    map { $ref->{$_} = $form->format_amount($myconfig, $ref->{$_}, 2)} qw(amount fee interest);
    if ($ref->{pastdue} >= $ref->{terms}) {
      push @{ $form->{DUNNINGS} }, $ref;
    }
  }

  $sth->finish;

  $query = qq|select id, dunning_description FROM dunning_config order by dunning_level|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{DUNNING_CONFIG} }, $ref;
  }

  $sth->finish;

  $dbh->disconnect;
  $main::lxdebug->leave_sub();
}

sub get_dunning {

  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $where = qq| WHERE 1=1 AND da.trans_id=a.id|;

  if ($form->{"$form->{vc}_id"}) {
    $where .= qq| AND a.$form->{vc}_id = $form->{"$form->{vc}_id"}|;
  } else {
    if ($form->{ $form->{vc} }) {
      $where .= " AND lower(ct.name) LIKE '$name'";
    }
  }

  my $sortorder = join ', ',
    ("a.id", $form->sort_columns(transdate, duedate, name));
  $sortorder = $form->{sort} if $form->{sort};

  $where .= " AND lower(ordnumber) LIKE '$form->{ordnumber}'" if $form->{ordnumber};
  $where .= " AND lower(invnumber) LIKE '$form->{invnumber}'" if $form->{invnumber};


  $form->{minamount} = $form->parse_amount($myconfig,$form->{minamount});
  $where .= " AND a.dunning_id='$form->{dunning_level}'"
    if $form->{dunning_level};
  $where .= " AND a.ordnumber ilike '%$form->{ordnumber}%'"
    if $form->{ordnumber};
  $where .= " AND a.invnumber ilike '%$form->{invnumber}%'"
    if $form->{invnumber};
  $where .= " AND a.notes ilike '%$form->{notes}%'"
    if $form->{notes};
  $where .= " AND ct.name ilike '%$form->{customer}%'"
    if $form->{customer};
  $where .= " AND a.amount > a.paid AND da.dunning_id=a.dunning_id " unless ($form->{showold});

  $where .= " AND a.transdate >='$form->{transdatefrom}' " if ($form->{transdatefrom});
  $where .= " AND a.transdate <='$form->{transdateto}' " if ($form->{transdateto});
  $where .= " AND da.transdate >='$form->{dunningfrom}' " if ($form->{dunningfrom});
  $where .= " AND da.transdate <='$form->{dunningto}' " if ($form->{dunningto});

  $where .= " ORDER by $sortorder";


  $query = qq|SELECT a.id, a.ordnumber, a.transdate, a.invnumber,a.amount, ct.name AS customername, a.duedate,da.fee ,da.interest, dn.dunning_description, da.transdate AS dunning_date, da.duedate AS dunning_duedate
	         FROM ar a
	         JOIN customer ct ON (a.customer_id = ct.id),
                 dunning da LEFT JOIN dunning_config dn ON (da.dunning_id=dn.id)
                 $where|;

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);


  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {

    map { $ref->{$_} = $form->format_amount($myconfig, $ref->{$_}, 2)} qw(amount fee interest);
    push @{ $form->{DUNNINGS} }, $ref;
  }

  $sth->finish;



  $dbh->disconnect;
  $main::lxdebug->leave_sub();
}


sub parse_strings {

  $main::lxdebug->enter_sub();

  my ($myconfig, $form, $userspath, $string) = @_;

  my $format = $form->{format};
  $form->{format} = "html";

  $tmpstring = "parse_string.html";
  $tmpfile = "$myconfig->{templates}/$tmpstring";
  open(OUT, ">$tmpfile") or $form->error("$tmpfile : $!");
  print(OUT $string);
  close(OUT);

  my $in = $form->{IN};
  $form->{IN} = $tmpstring;
  $template = HTMLTemplate->new($tmpstring, $form, $myconfig, $userspath);

  my $fileid = time;
  $form->{tmpfile} = "$userspath/${fileid}.$tmpstring";
  $out = $form->{OUT};
  $form->{OUT} = ">$form->{tmpfile}";

  if ($form->{OUT}) {
    open(OUT, "$form->{OUT}") or $form->error("$form->{OUT} : $!");
  }
  if (!$template->parse(*OUT)) {
    $form->cleanup();
    $form->error("$form->{IN} : " . $template->get_error());
  }
  
  close(OUT);
  my $result = "";
  open(IN, $form->{tmpfile}) or $form->error($form->cleanup . "$form->{tmpfile} : $!");

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
  
  foreach my $file (@{ $form->{DUNNING_PDFS} }) {
    $inputfiles .= " $userspath/$file ";
  }

  my $outputfile = "$userspath/dunning.pdf";
  system("gs -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -sOutputFile=$outputfile $inputfiles");
  foreach my $file (@{ $form->{DUNNING_PDFS} }) {
    unlink("$userspath/$file");
  }
  $out="";


     $form->{OUT} = $out;

      my $numbytes = (-s $outputfile);
      open(IN, $outputfile)
        or $form->error($self->cleanup . "$outputfile : $!");

      $form->{copies} = 1 unless $form->{media} eq 'printer';

      chdir("$self->{cwd}");

      for my $i (1 .. $form->{copies}) {
        if ($form->{OUT}) {
          open(OUT, $form->{OUT})
            or $form->error($form->cleanup . "$form->{OUT} : $!");
        } else {

          # launch application
          print qq|Content-Type: Application/PDF
Content-Disposition: attachment; filename="$outputfile"
Content-Length: $numbytes

|;

          open(OUT, ">-") or $form->error($form->cleanup . "$!: STDOUT");

        }

        while (<IN>) {
          print OUT $_;
        }

        close(OUT);

        seek IN, 0, 0;
      }

      close(IN);
  unlink("$userspath/$outputfile");

  $main::lxdebug->leave_sub();
}

1;
