#=====================================================================
# LX-Office ERP
# Copyright (C) 2008
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
#
# Letter module
#
#======================================================================

use strict;
use POSIX qw(strftime);

use SL::GenericTranslations;
use SL::ReportGenerator;
use SL::Letter;
use SL::CT;
use SL::DB::Contact;
use SL::DB::Default;
use SL::Helper::CreatePDF;
use SL::Helper::Flash;
require "bin/mozilla/reportgenerator.pl";
require "bin/mozilla/io.pl";
require "bin/mozilla/arap.pl";

use constant TEXT_CREATED_FOR_VALUES => (qw(presskit fax letter));
use constant PAGE_CREATED_FOR_VALUES => (qw(sketch 1 2));

our ($form, %myconfig, $locale, $lxdebug);

# parserhappy(R)
# $locale->text('Presskit')
# $locale->text('Sketch')
# $locale->text('Fax')
# $locale->text('Letter')

sub add {
  $::lxdebug->enter_sub;

  $main::auth->assert('sales_letter_edit');
  my %params = @_;

  return $main::lxdebug->leave_sub if load_letter_draft();

  my $letter = SL::Letter->new(%params);

  if (my $cp_id = delete $::form->{contact_id}) {
    my $contact = SL::DB::Manager::Contact->find_by(cp_id => $cp_id);
    $letter->{cp_id}     = $contact->cp_id;
    $letter->{vc_id}     = $contact->cp_cv_id;
    $letter->{greeting}  = GenericTranslations->get(
      translation_type => 'greetings::' . ($contact->{cp_gender} eq 'f' ? 'female' : 'male'),
      language_id      => $contact->language_id,
      allow_fallback   => 1
    );
    $params{language_id} = $contact->language_id;
  }

  $letter->check_date;

  _display(
    letter      => $letter,
    title       => $locale->text('Add Letter'),
    language_id => $params{language_id},
  );

  $::lxdebug->leave_sub;
}

sub edit {
  $::lxdebug->enter_sub;

  $main::auth->assert('sales_letter_edit');
  add() unless ($form->{id});

  my $letter = SL::Letter->new( id => $form->{id}, draft => $form->{draft} )->load;

  add() unless $letter && ($letter->{id} || $letter->{draft_id});

  _display(
    letter => $letter,
    title  => $locale->text('Edit Letter'),
  );

  $::lxdebug->leave_sub;
}

sub save {
  $::lxdebug->enter_sub;

  $main::auth->assert('sales_letter_edit');
  my %params = @_;


  $::form->error(t8('The subject is missing.')) unless $form->{letter}->{subject};
  $::form->error(t8('The body is missing.')) unless $form->{letter}->{body};
  $::form->error(t8('The employee is missing.')) unless $form->{letter}->{employee_id};

  my $letter = _update();

  $letter->check_number;
  $letter->save;

  $form->{SAVED_MESSAGE} = $locale->text('Letter saved!');

  _display(
    letter => $letter,
  );

  $::lxdebug->leave_sub;
}

sub save_letter_draft {
  $::lxdebug->enter_sub;

  $main::auth->assert('sales_letter_edit');

  $::form->error(t8('The subject is missing.')) unless $form->{letter}->{subject};
  $::form->error(t8('The body is missing.')) unless $form->{letter}->{body};
  $::form->error(t8('The employee is missing.')) unless $form->{letter}->{employee_id};
  $::form->error(t8('Already as letter saved.')) if $form->{letter}->{letternumber};

  my $letter_draft = _update();
  $letter_draft->{draft_id} = delete $letter_draft->{id}; # if we have one
  $letter_draft->save(draft => '1');
  $letter_draft->{vergiss_mich_nicht} = 'nicht vergessen';
  $form->{SAVED_MESSAGE} = $locale->text('Draft for this Letter saved!');

  _display(
    letter => $letter_draft,
  );

  $::lxdebug->leave_sub;
}

sub delete {
  $main::lxdebug->enter_sub();

  $main::auth->assert('sales_letter_edit');
  # NYI
  $form->{SAVED_MESSAGE} = $locale->text('Not yet implemented!');
  _display();

  $main::lxdebug->leave_sub();
}

sub delete_letter_drafts {
  $main::lxdebug->enter_sub();

  $main::auth->assert('sales_letter_edit');

  my @ids;
  foreach (keys %{$form}) {
    push @ids, $1 if (/^checked_(.*)/ && $form->{$_});
  }

  SL::Letter->delete_drafts(@ids) if (@ids); #->{id});

  add();

  $main::lxdebug->leave_sub();
}

sub _display {
  $main::lxdebug->enter_sub();

  $main::auth->assert('sales_letter_edit');
  my %params = @_;

  my $letter = $params{letter};

  my %TMPL_VAR;

  $form->{type}             = 'letter';   # needed for print_options
  $form->{vc}               = 'customer'; # needs to be for _get_contacts...
  $form->{"$form->{vc}_id"} ||= $letter->{customer_id};
  $form->{jsscript}         = 1;
  $form->{javascript}       =
     qq|<script type="text/javascript" src="js/customer_or_vendor_selection.js"></script>
        <script type="text/javascript" src="js/edit_part_window.js"></script>|;

  $form->get_lists("contacts"      => "ALL_CONTACTS",
  "employees"     => "ALL_EMPLOYEES",
                   "salesmen"      => "ALL_SALESMEN",
                   "departments"   => "ALL_DEPARTMENTS",
                   "languages"     => "languages",
                   "customers"     => { key   => "ALL_CUSTOMERS",
                                        limit => $myconfig{vclimit} + 1 },
                   "vc"            => 'customer',
                   );

  $TMPL_VAR{vc_keys}       = sub { "$_[0]->{name}--$_[0]->{id}" };
  $TMPL_VAR{vc_select}     = "customer_or_vendor_selection_window('letter.customer', '', 0, 0)";
  $TMPL_VAR{ct_labels}     = sub { ($_[0]->{cp_greeting} ? "$_[0]->{cp_greeting} " : '') .  $_[0]->{cp_name} .  ($_[0]->{cp_givenname} ? ", $_[0]->{cp_givenname}" : '') };
  $TMPL_VAR{TCF}           = [ map { key => $_, value => $locale->text(ucfirst $_) }, TEXT_CREATED_FOR_VALUES() ];
  $TMPL_VAR{PCF}           = [ map { key => $_, value => $locale->text(ucfirst $_) }, PAGE_CREATED_FOR_VALUES() ];

  $form->header();

  $form->{language_id} ||= $params{language_id};

  print $form->parse_html_template('letter/edit', {
    %params,
    %TMPL_VAR,
    letter        => $letter,
    print_options => print_options(inline => 1),
  });

  $main::lxdebug->leave_sub();
}

sub search {
  $lxdebug->enter_sub();

  $main::auth->assert('sales_letter_report');

  $form->get_lists("employees" => "EMPLOYEES",
                   "salesmen"  => "SALESMEN",
                   "customers" => "ALL_CUSTOMERS");

  $form->{jsscript} = 1;
  $form->{title}    = $locale->text('Letters');

  $form->header();
  print $form->parse_html_template('letter/search');

  $lxdebug->leave_sub();
}

sub report {
  $lxdebug->enter_sub();

  $main::auth->assert('sales_letter_report');

  my %params = @_;

  my @report_params = qw(letternumber subject body contact date_from date_to cp_id);

  if ($form->{selectcustomer}) {
    push @report_params, 'customer_id';
    $form->{customer_id} = $form->{customer};
  } else {
    push @report_params, 'customer';
  }

  report_generator_set_default_sort('date', 1);

  %params = (%params, map { $_ => $form->{$_} } @report_params);

  my @letters       = SL::Letter->find(%params);

  $form->{rowcount} = @letters;
  $form->{title}    = $locale->text('Letters');

  my %column_defs = (
    'date'                  => { 'text' => $locale->text('Date'), },
    'subject'               => { 'text' => $locale->text('Subject'), },
    'letternumber'          => { 'text' => $locale->text('Letternumber'), },
    'customer'              => { 'text' => $locale->text('Customer') },
    'contact'               => { 'text' => $locale->text('Contact') },
    'date'                  => { 'text' => $locale->text('Date') },
  );

  my @columns = qw(date subject letternumber customer contact date);
  my $href    = build_std_url('action=report', grep { $form->{$_} } @report_params);

  my @sortable_columns = qw(date subject letternumber customer contact date);

  foreach my $name (@sortable_columns) {
    my $sortdir                 = $form->{sort} eq $name ? 1 - $form->{sortdir} : $form->{sortdir};
    $column_defs{$name}->{link} = $href . "&sort=$name&sortdir=$sortdir";
  }

  my @options;

  # option line

  push @options, $locale->text('Subject')                  . " : $form->{subject}"   if ($form->{subject});
  push @options, $locale->text('Body')                     . " : $form->{body}"      if ($form->{body});

  my @hidden_report_params = map { +{ 'key' => $_, 'value' => $form->{$_} } } @report_params;

  my $report = SL::ReportGenerator->new(\%myconfig, $form, 'std_column_visibility' => 1);

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);

  $report->set_export_options('report', @report_params);

  $report->set_sort_indicator($form->{sort}, $form->{sortdir});

  $report->set_options('raw_top_info_text'    => $form->parse_html_template('letter/report_top',    { 'OPTIONS' => \@options }),
                       'raw_bottom_info_text' => $form->parse_html_template('letter/report_bottom', { 'HIDDEN'  => \@hidden_report_params }),
                       'output_format'        => 'HTML',
                       'title'                => $form->{title},
                       'attachment_basename'  => $locale->text('letters_list') . strftime('_%Y%m%d', localtime time),
    );
  $report->set_options_from_form();

  my $idx      = 0;
  my $callback = build_std_url('action=report', grep { $form->{$_} } @report_params);
  my $edit_url = build_std_url('action=edit', 'callback=' . E($callback));

  foreach my $l (@letters) {
    $idx++;

    my $row = { map { $_ => { 'data' => $l->{$_} } } keys %{ $l } };

    $row->{subject}->{link}      = $edit_url . '&id=' . Q($l->{id});
    $row->{letternumber}->{link} = $edit_url . '&id=' . Q($l->{id});

    $report->add_data($row);
  }

  $report->generate_with_headers();

  $lxdebug->leave_sub();
}

sub print_letter {
  $lxdebug->enter_sub();

  $main::auth->assert('sales_letter_edit');

  my ($old_form) = @_;

  my $display_form = $form->{display_form} || "display_form";
  my $letter       = _update();

  $letter->export_to($form);
  $form->{formname} = "letter";
  $form->{format} = "pdf";

  my $language_saved      = $form->{language_id};
  my $greeting_saved      = $form->{greeting};
  my $cp_id_saved         = $form->{cp_id};

  call_sub("customer_details");

  if (!$cp_id_saved) {
    # No contact was selected. Delete all contact variables because
    # IS->customer_details() and IR->vendor_details() get the default
    # contact anyway.
    map({ delete($form->{$_}); } grep(/^cp_/, keys(%{ $form })));
  }

  $form->{greeting} = $greeting_saved;
  $form->{language_id} = $language_saved;

  if ($form->{cp_id}) {
    CT->get_contact(\%myconfig, $form);
  }

  $form->{cp_contact_formal} = ($form->{cp_greeting} ? "$form->{cp_greeting} " : '') . ($form->{cp_givenname} ? "$form->{cp_givenname} " : '') . $form->{cp_name};

  $form->get_employee_data('prefix' => 'employee', 'id' => $letter->{employee_id});
  $form->get_employee_data('prefix' => 'salesman', 'id' => $letter->{salesman_id});

  my %create_params = (
    template  => scalar(SL::Helper::CreatePDF->find_template(
      name        => 'letter',
      printer_id  => $::form->{printer_id},
      language_id => $::form->{language_id},
      formname    => 'letter',
      format      => 'pdf',
    )),
    variables => $::form,
    return    => 'file_name',
  );
  my $pdf_file_name;
  eval {
    $pdf_file_name = SL::Helper::CreatePDF->create_pdf(%create_params);

    if ( $::form->{media} eq 'email') {
      my $mail             = Mailer->new;
      my $signature        = $::myconfig{signature};
      $mail->{$_}          = $::form->{$_}               for qw(cc subject message bcc to);
      $mail->{from}        = qq|"$::myconfig{name}" <$::myconfig{email}>|;
      $mail->{fileid}      = time() . '.' . $$ . '.';
      $mail->{attachments} =  [{ "filename" => $pdf_file_name,
                                 "name"     => $::form->{attachment_name} }];
      $mail->{message}    .=  "\n-- \n$signature";
      $mail->{message}     =~ s/\r//g;

      my $err = $mail->send;
# TODO
#       $self
#           ->js
#           ->flash($err?'error':'info',
#                   $err?t8('A mail error occurred: #1', $err):
#                        t8('The document have been sent to \'#1\'.', $mail->{to}))
#           ->render($self);
      return $err?0:1;
    }

    if (!$::form->{printer_id}) {
      my $file = IO::File->new($pdf_file_name, 'r') || croak("Cannot open file '$pdf_file_name'");
      my $size = -s $pdf_file_name;
      my $content_type    =  'application/pdf';
      my $attachment_name =  $::form->generate_attachment_filename;
      $attachment_name    =~ s:.*//::g;

      print $::form->create_http_response(content_type        => $content_type,
                                          content_disposition => 'attachment; filename="' . $attachment_name . '"',
                                          content_length      => $size);

      $::locale->with_raw_io(\*STDOUT, sub { print while <$file> });
      $file->close;
      unlink $pdf_file_name;
      return 1;
    }

    my $printer = SL::DB::Printer->new(id => $::form->{printer_id})->load;
    my $command = SL::Template::create(type => 'ShellCommand', form => Form->new(''))->parse($printer->printer_command);

    open my $out, '|-', $command or die $!;
    binmode $out;
    print $out scalar(read_file($pdf_file_name));
    close $out;

    flash_later('info', t8('The documents have been sent to the printer \'#1\'.', $printer->printer_description));
    my $callback = build_std_url('letter.pl', 'action=edit', 'id=' . $letter->{id}, 'printer_id');
    $::form->redirect;
    1;
  } or do {
    unlink $pdf_file_name;
    $::form->error(t8("Creating the PDF failed:") . " " . $@);
  };

  $lxdebug->leave_sub();
}

sub update {
  $::lxdebug->enter_sub;

  $main::auth->assert('sales_letter_edit');

  my $name_selected = shift;

  _display(
    letter => _update(
      _name_selected => $name_selected,
    ),
  );

  $::lxdebug->leave_sub;
}

sub _update {
  $::lxdebug->enter_sub;

  $main::auth->assert('sales_letter_edit');

  my %params = @_;

  my $from_letter = $::form->{letter};

  my $letter      = SL::Letter->new( id => $from_letter->{id} )
                              ->load
                              ->update_from($from_letter);

  $letter->check_name(%params);
  $letter->check_date;
  $letter->set_greetings;

  $::lxdebug->leave_sub;

  return $letter;
}

sub letter_tab {
  $::lxdebug->enter_sub;

  $main::auth->assert('sales_letter_edit');

  my @report_params = qw(letternumber subject contact date);

  my @letters       = SL::Letter->find(map { $_ => $form->{$_} } @report_params);

  $::lxdebug->leave_sub;
}

sub e_mail {
  $::lxdebug->enter_sub;

  $main::auth->assert('sales_letter_edit');
  my $letter = _update();

  $letter->check_number;
  $letter->save;

  $letter->export_to($::form);

  $::form->{id} = $letter->{id};
  edit_e_mail();

  $::lxdebug->leave_sub;
}

sub dispatcher {
  $main::lxdebug->enter_sub();
  # dispatch drafts
  my $locale   = $main::locale;


  if ($form->{letter_draft_action} eq $locale->text("Skip")) {
    $form->{DONT_LOAD_DRAFT} = 1;
    add();
    return 1;
  } elsif ($form->{letter_draft_action} eq $locale->text("Delete drafts")) {
    delete_letter_drafts();
    return 1;
  }

  foreach my $action (qw(e_mail print save update save_letter_draft)) {
    if ($::form->{"action_${action}"}) {
      $::form->{dispatched_action} = $action;
      call_sub($action);
      return;
    }
  }

  $::form->error($::locale->text('No action defined.'));
  $::lxdebug->leave_sub;
}

sub continue {
  call_sub($form->{nextsub});
}


sub load_letter_draft {
  $lxdebug->enter_sub();

  $main::auth->assert('sales_letter_edit');
 $main::lxdebug->leave_sub() and return 0 if ($form->{DONT_LOAD_DRAFT});
 $form->{title}    = $locale->text('Letter Draft');
 $form->{script}   = 'letter.pl';

  my @letter_drafts = SL::Letter->find(draft => 1);

  return unless @letter_drafts;
  $form->header();
  print $form->parse_html_template('letter/load_drafts', { LETTER_DRAFTS => \@letter_drafts });

  return 1;
  $lxdebug->leave_sub();
}

1;
