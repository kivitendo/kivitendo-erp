package SL::Controller::Letter;

use strict;
use parent qw(SL::Controller::Base);

use Carp;
use File::Basename;
use POSIX qw(strftime);
use SL::Controller::Helper::GetModels;
use SL::Controller::Helper::ReportGenerator;
use SL::CT;
use SL::DB::Letter;
use SL::DB::LetterDraft;
use SL::DB::Employee;
use SL::Helper::Flash qw(flash flash_later);
use SL::Helper::CreatePDF;
use SL::Helper::PrintOptions;
use SL::Locale::String qw(t8);
use SL::IS;
use SL::ReportGenerator;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(letter all_employees models) ],
);

__PACKAGE__->run_before('check_auth_edit');
__PACKAGE__->run_before('check_auth_report', only => [ qw(list) ]);

use constant TEXT_CREATED_FOR_VALUES => (qw(presskit fax letter));
use constant PAGE_CREATED_FOR_VALUES => (qw(sketch 1 2));

my %sort_columns = (
  date                  => t8('Date'),
  subject               => t8('Subject'),
  letternumber          => t8('Letternumber'),
  vc_id                 => t8('Customer'),
  contact               => t8('Contact'),
);

sub action_add {
  my ($self, %params) = @_;

  return if $self->load_letter_draft(%params);

  $self->letter->employee_id(SL::DB::Manager::Employee->current->id);
  $self->letter->salesman_id(SL::DB::Manager::Employee->current->id);

  $self->_display(
    title       => t8('Add Letter'),
    language_id => $params{language_id},
  );
}

sub action_edit {
  my ($self, %params) = @_;

  return $self->action_add
    unless $::form->{letter} || $::form->{draft};

  $self->letter(SL::DB::Letter->new_from_draft($::form->{draft}{id}))
    if $::form->{draft};

  $self->_display(
    title  => t8('Edit Letter'),
  );
}

sub action_save {
  my ($self, %params) = @_;

  my $letter = $self->_update;

  if (!$self->check_letter($letter)) {
    return $self->_display;
  }

  $self->check_number;

  if (!$letter->save) {
    flash('error', t8('There was an error saving the letter'));
    return $self->_display;
  }

  flash('info', t8('Letter saved!'));

  $self->_display;
}

sub action_update_contacts {
  my ($self) = @_;

  my $letter = $self->letter;

  if (!$self->letter->vc_id || !$self->letter->customer) {
    return $self->js
      ->replaceWith(
        '#letter_cp_id',
        SL::Presenter->get->select_tag('letter.cp_id', [], value_key => 'cp_id', title_key => 'full_name')
      )
      ->render;
  }

  my $contacts = $letter->customer->contacts;

  my $default;
  if (   $letter->contact
      && $letter->contact->cp_cv_id
      && $letter->contact->cp_cv_id == $letter->vc_id) {
    $default = $letter->contact->cp_id;
  } else {
    $default = '';
  }

  $self->js
    ->replaceWith(
      '#letter_cp_id',
      SL::Presenter->get->select_tag('letter.cp_id', $contacts, default => $default, value_key => 'cp_id', title_key => 'full_name')
    )
    ->render;
}

sub action_save_letter_draft {
  my ($self, %params) = @_;

  $self->check_letter;

  my $letter_draft = SL::DB::LetterDraft->new_from_letter($self->_update);

  if (!$letter_draft->save) {
    flash('error', t8('There was an error saving the letter draft'));
    return $self->_display;
  }

  flash('info', t8('Draft for this Letter saved!'));

  $self->_display;
}

sub action_delete {
  my ($self, %params) = @_;

  if (!$self->letter->delete) {
    flash('error', t8('An error occured. Letter could not be deleted.'));
    return $self->action_update;
  }

  flash_later('info', t8('Letter deleted'));
  $self->redirect_to(action => 'list');
}

sub action_delete_letter_drafts {
  my ($self, %params) = @_;

  my @ids =  grep { /^checked_(.*)/ && $::form->{$_} } keys %$::form;

  SL::DB::Manager::LetterDraft->delete_all(query => [ ids => \@ids ]) if @ids;

  $self->redirect_to(action => 'add');
}

sub action_list {
  my ($self, %params) = @_;

  $self->make_filter_summary;
  $self->prepare_report;

  my $letters = $self->models->get;
  $self->report_generator_list_objects(report => $self->{report}, objects => $letters);

}

sub action_print_letter {
  my ($self, $old_form) = @_;

  my $display_form = $::form->{display_form} || "display_form";
  my $letter       = $self->_update;

  $self->export_letter_to_form($letter);
  $::form->{formname} = "letter";
  $::form->{type}     = "letter";
  $::form->{format}   = "pdf";

  my $language_saved      = $::form->{language_id};
  my $greeting_saved      = $::form->{greeting};
  my $cp_id_saved         = $::form->{cp_id};

  $::form->{customer_id} = $self->letter->vc_id;
  IS->customer_details(\%::myconfig, $::form);

  if (!$cp_id_saved) {
    # No contact was selected. Delete all contact variables because
    # IS->customer_details() and IR->vendor_details() get the default
    # contact anyway.
    map({ delete($::form->{$_}); } grep(/^cp_/, keys(%{ $::form })));
  }

  $::form->{greeting} = $greeting_saved;
  $::form->{language_id} = $language_saved;

  if ($::form->{cp_id}) {
    CT->get_contact(\%::myconfig, $::form);
  }

  $::form->{cp_contact_formal} = ($::form->{cp_greeting} ? "$::form->{cp_greeting} " : '') . ($::form->{cp_givenname} ? "$::form->{cp_givenname} " : '') . $::form->{cp_name};

  $::form->get_employee_data('prefix' => 'employee', 'id' => $letter->{employee_id});
  $::form->get_employee_data('prefix' => 'salesman', 'id' => $letter->{salesman_id});

  my ($template_file, @template_files) = SL::Helper::CreatePDF->find_template(
    name        => 'letter',
    printer_id  => $::form->{printer_id},
    language_id => $::form->{language_id},
    formname    => 'letter',
    format      => 'pdf',
  );

  if (!defined $template_file) {
    $::form->error($::locale->text('Cannot find matching template for this print request. Please contact your template maintainer. I tried these: #1.', join ', ', map { "'$_'"} @template_files));
  }

  my %create_params = (
    template  => $template_file,
    variables => $::form,
    return    => 'file_name',
    variable_content_types => {
      body                 => 'html',
    },
  );

  my $pdf_file_name;
  eval {
    $pdf_file_name = SL::Helper::CreatePDF->create_pdf(%create_params);

    # set some form defaults for printing webdav copy variables
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

      # copy_file_to_webdav was already done via io.pl -> edit_e_mail
      my $err = $mail->send;
      return !$err;
    }

    my $webdav_copy_args   = Form->new('');
    %{ $webdav_copy_args } = (
      %{ $::form },
      tmpdir  => dirname($pdf_file_name),
      tmpfile => basename($pdf_file_name),
      cwd     => POSIX::getcwd(),
    );

    if (!$::form->{printer_id} || $::form->{media} eq 'screen') {

      my $file = IO::File->new($pdf_file_name, 'r') || croak("Cannot open file '$pdf_file_name'");
      my $size = -s $pdf_file_name;
      my $content_type    =  'application/pdf';
      $::form->{letternumber} = $self->letter->letternumber;
      my $attachment_name =  $::form->generate_attachment_filename;
      $attachment_name    =~ s:.*//::g;

      print $::form->create_http_response(content_type        => $content_type,
                                          content_disposition => 'attachment; filename="' . $attachment_name . '"',
                                          content_length      => $size);

      $::locale->with_raw_io(\*STDOUT, sub { print while <$file> });
      $file->close;

      Common::copy_file_to_webdav_folder($webdav_copy_args) if $::instance_conf->get_webdav_documents;
      unlink $pdf_file_name;
      return 1;
    }

    my $printer = SL::DB::Printer->new(id => $::form->{printer_id})->load;
    $printer->print_document(
      copies    => $::form->{copies},
      file_name => $pdf_file_name,
    );

    Common::copy_file_to_webdav_folder($webdav_copy_args) if $::instance_conf->get_webdav_documents;

    unlink $pdf_file_name;

    flash_later('info', t8('The documents have been sent to the printer \'#1\'.', $printer->printer_description));
    $self->redirect_to(action => 'edit', 'letter.id' => $self->letter->id, media => 'printer', printer_id => $::form->{printer_id});
    1;
  } or do {
    unlink $pdf_file_name;
    $::form->error(t8("Creating the PDF failed:") . " " . $@);
  };

}

sub action_update {
  my ($self, $name_selected) = @_;

  $self->_display(
    letter => $self->_update,
  );
}

sub action_skip_draft {
  my ($self) = @_;
  $self->action_add(skip_drafts => 1);
}

sub action_delete_drafts {
  my ($self) = @_;
  delete_letter_drafts();
  $self->action_add(skip_drafts => 1);
}

sub _display {
  my ($self, %params) = @_;

  $::request->{layout}->use_javascript("${_}.js") for qw(ckeditor/ckeditor ckeditor/adapters/jquery);

  my $letter = $self->letter;

 $params{title} ||= t8('Edit Letter');

  $::form->{type}             = 'letter';   # needed for print_options
  $::form->{vc}               = 'customer'; # needs to be for _get_contacts...

  $::request->layout->add_javascripts('customer_or_vendor_selection.js');
  $::request->layout->add_javascripts('edit_part_window.js');

  $::form->{language_id} ||= $params{language_id};
  $::form->{printers}      = SL::DB::Manager::Printer->get_all_sorted;

  $self->render('letter/edit',
    %params,
    TCF           => [ map { key => $_, value => t8(ucfirst $_) }, TEXT_CREATED_FOR_VALUES() ],
    PCF           => [ map { key => $_, value => t8(ucfirst $_) }, PAGE_CREATED_FOR_VALUES() ],
    letter        => $letter,
    employees     => $self->all_employees,
    print_options => SL::Helper::PrintOptions->get_print_options (
      options => { no_postscript   => 1,
                   no_opendocument => 1,
                   no_html         => 1,
                   no_queue        => 1 }),

  );
}

sub _update {
  my ($self, %params) = @_;

  my $letter = $self->letter;

  $self->check_date;
  $self->set_greetings;

  return $letter;
}

sub prepare_report {
  my ($self) = @_;

  my $report      = SL::ReportGenerator->new(\%::myconfig, $::form);
  $self->{report} = $report;

  my @columns  = qw(date subject letternumber vc_id contact date);
  my @sortable = qw(date subject letternumber vc_id contact date);

  my %column_defs = (
    date                  => { text => t8('Date'),         sub => sub { $_[0]->date_as_date } },
    subject               => { text => t8('Subject'),      sub => sub { $_[0]->subject },
                               obj_link => sub { $self->url_for(action => 'edit', 'letter.id' => $_[0]->id, callback => $self->models->get_callback) }  },
    letternumber          => { text => t8('Letternumber'), sub => sub { $_[0]->letternumber },
                               obj_link => sub { $self->url_for(action => 'edit', 'letter.id' => $_[0]->id, callback => $self->models->get_callback) }  },
    vc_id                 => { text => t8('Customer'),      sub => sub { SL::DB::Manager::Customer->find_by_or_create(id => $_[0]->vc_id)->displayable_name } },
    contact               => { text => t8('Contact'),       sub => sub { $_[0]->contact ? $_[0]->contact->full_name : '' } },
  );

  $column_defs{$_}{text} = $sort_columns{$_} for keys %column_defs;

  $report->set_options(
    std_column_visibility => 1,
    controller_class      => 'Letter',
    output_format         => 'HTML',
    top_info_text         => t8('Letters'),
    title                 => t8('Letters'),
    allow_pdf_export      => 1,
    allow_csv_export      => 1,
  );

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_export_options(qw(list filter));
  $report->set_options_from_form;

  $self->models->disable_plugin('paginated') if $report->{options}{output_format} =~ /^(pdf|csv)$/i;
  $self->models->finalize;
  $self->models->set_report_generator_sort_options(report => $report, sortable_columns => \@sortable);

  $report->set_options(
    raw_top_info_text    => $self->render('letter/report_top',    { output => 0 }),
    raw_bottom_info_text => $self->render('letter/report_bottom', { output => 0 }, models => $self->models),
    attachment_basename  => t8('letters_list') . strftime('_%Y%m%d', localtime time),
  );
}

sub make_filter_summary {
  my ($self) = @_;

  my $filter = $::form->{filter} || {};
  my @filter_strings;

  my $employee = $filter->{employee_id} ? SL::DB::Employee->new(id => $filter->{employee_id})->load->name : '';
  my $salesman = $filter->{salesman_id} ? SL::DB::Employee->new(id => $filter->{salesman_id})->load->name : '';

  my @filters = (
    [ $filter->{"letternumber:substr::ilike"},  t8('Number')     ],
    [ $filter->{"subject:substr::ilike"},       t8('Subject')    ],
    [ $filter->{"body:substr::ilike"},          t8('Body')       ],
    [ $filter->{"date:date::ge"},               t8('From Date')  ],
    [ $filter->{"date:date::le"},               t8('To Date')    ],
    [ $employee,                                t8('Employee')   ],
    [ $salesman,                                t8('Salesman')   ],
  );

  my %flags = (
  );
  my @flags = map { $flags{$_} } @{ $filter->{part}{type} || [] };

  for (@flags) {
    push @filter_strings, $_ if $_;
  }
  for (@filters) {
    push @filter_strings, "$_->[1]: $_->[0]" if $_->[0];
  }

  $self->{filter_summary} = join ', ', @filter_strings;
}

sub e_mail {
  my $letter = _update();

  $letter->check_number;
  $letter->save;

  $::form->{formname} = "letter";
  $letter->export_to($::form);

  $::form->{id} = $letter->{id};
  edit_e_mail();
}

sub load_letter_draft {
  my ($self, %params) = @_;

  return 0 if $params{skip_drafts};

  my $letter_drafts = SL::DB::Manager::LetterDraft->get_all;

  return unless @$letter_drafts;

  $self->render('letter/load_drafts',
    title         => t8('Letter Draft'),
    LETTER_DRAFTS => $letter_drafts,
  );

  return 1;
}

sub check_date {
  my ($self) = @_;
  my $letter = $self->letter;

  return unless $letter;
  return if $letter->date;

  $letter->date(DateTime->today)
}

sub check_letter {
  my ($self, $letter) = @_;

  $letter ||= $self->letter;

  my $error;

  if (!$letter->subject) {
    flash('error', t8('The subject is missing.'));
    $error = 1;
  }
  if (!$letter->body) {
    flash('error', t8('The body is missing.'));
    $error = 1;
  }
  if (!$letter->employee_id) {
    flash('error', t8('The employee is missing.'));
    $error = 1;
  }

  return !$error;
}

sub check_number {
  my ($self, $letter) = @_;

  $letter ||= $self->letter;

  return if $letter->letternumber;

  $letter->letternumber(SL::TransNumber->new(type => 'letter', id => $self->{id}, number => $self->{letternumber})->create_unique);
}

sub set_greetings {
  my ($self) = @_;
  my $letter = $self->letter;

  return unless $letter;
  return if $letter->greeting;

  $letter->greeting(t8('Dear Sir or Madam,'));
}

sub export_letter_to_form {
  my ($self, $letter) = @_;
  # nope, not pretty.

  $letter ||= $self->letter;

  for ($letter->meta->columns) {
    if ((ref $_) =~ /Date/i) {
      $::form->{$_->name} = $letter->$_->to_kivitendo;
    } else {
      $::form->{$_->name} = $letter->$_;
    }
  }
}

sub init_letter {
  my ($self) = @_;

  my $letter      = SL::DB::Manager::Letter->find_by_or_create(id => $::form->{letter}{id} || 0)
                                           ->assign_attributes(%{ $::form->{letter} });

  if ($letter->cp_id) {
#     $letter->vc_id($letter->contact->cp_cv_id);
      # contacts don't have language_id yet
#     $letter->greeting(GenericTranslations->get(
#       translation_type => 'greetings::' . ($letter->contact->cp_gender eq 'f' ? 'female' : 'male'),
#       language_id      => $letter->contact->language_id,
#       allow_fallback   => 1
#     ));
  }

  $letter;
}

sub init_models {
  my ($self) = @_;

  SL::Controller::Helper::GetModels->new(
    controller   => $self,
    model        => 'Letter',
    sorted       => \%sort_columns,
    with_objects => [ 'contact', 'salesman', 'employee' ],
  );
}

sub init_all_employees {
  SL::DB::Manager::Employee->get_all(query => [ deleted => 0 ]);
}

sub check_auth_edit {
  $::auth->assert('sales_letter_edit');
}

sub check_auth_report {
  $::auth->assert('sales_letter_report');
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::Letter - Letters CRUD and printing

=head1 DESCRIPTION

Simple letter CRUD controller with drafting capabilities.

=head1 TODO

  Customer/Vendor switch for dealing with vendor letters

copy to webdav is crap

customer/vendor stuff

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
