package SL::Controller::Letter;

use strict;
use parent qw(SL::Controller::Base);

use Carp;
use File::Basename;
use POSIX qw(strftime);
use SL::Controller::Helper::GetModels;
use SL::Controller::Helper::ReportGenerator;
use SL::CT;
use SL::DB::Employee;
use SL::DB::Language;
use SL::DB::Letter;
use SL::DB::LetterDraft;
use SL::DB::Printer;
use SL::Helper::Flash qw(flash flash_later);
use SL::Helper::CreatePDF;
use SL::Helper::PrintOptions;
use SL::Locale::String qw(t8);
use SL::Mailer;
use SL::IS;
use SL::Presenter::Tag qw(select_tag);
use SL::ReportGenerator;
use SL::Webdav;
use SL::Webdav::File;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(letter all_employees models webdav_objects is_sales) ],
);

__PACKAGE__->run_before('check_auth_edit');
__PACKAGE__->run_before('check_auth_report', only => [ qw(list) ]);

use constant TEXT_CREATED_FOR_VALUES => (qw(presskit fax letter));
use constant PAGE_CREATED_FOR_VALUES => (qw(sketch 1 2));

my %sort_columns = (
  date                  => t8('Date'),
  subject               => t8('Subject'),
  letternumber          => t8('Letternumber'),
  customer_id           => t8('Customer'),
  vendor_id             => t8('Vendor'),
  contact               => t8('Contact'),
);

### actions

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

  if ($::form->{draft}) {
    $self->letter(SL::DB::Letter->new_from_draft($::form->{draft}{id}));
    $self->is_sales($self->letter->is_sales);
  }

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

  if (!$self->letter->has_customer_vendor) {
    return $self->js
      ->replaceWith(
        '#letter_cp_id',
        SL::Presenter->get->select_tag('letter.cp_id', [], value_key => 'cp_id', title_key => 'full_name')
      )
      ->render;
  }

  my $contacts = $letter->customer_vendor->contacts;

  my $default;
  if (   $letter->contact
      && $letter->contact->cp_cv_id
      && $letter->contact->cp_cv_id == $letter->customer_vendor_id) {
    $default = $letter->contact->cp_id;
  } else {
    $default = '';
  }

  $self->js
    ->replaceWith(
      '#letter_cp_id',
      select_tag('letter.cp_id', $contacts, default => $default, value_key => 'cp_id', title_key => 'full_name')
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

  $self->setup_list_action_bar;
  $self->make_filter_summary;
  $self->prepare_report;

  my $letters = $self->models->get;
  $self->report_generator_list_objects(report => $self->{report}, objects => $letters);

}

sub action_print_letter {
  my ($self, %params) = @_;

  my $display_form = $::form->{display_form} || "display_form";
  my $letter       = $self->_update;

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

  my %result;
  eval {
    %result = SL::Template::LaTeX->parse_and_create_pdf(
      $template_file,
      SELF          => $self,
      FORM          => $::form,
      letter        => $letter,
      template_meta => {
        formname  => 'letter',
        language  => SL::DB::Language->new,
        extension => 'pdf',
        format    => $::form->{format},
        media     => $::form->{media},
        printer   => SL::DB::Manager::Printer->find_by_or_create(id => $::form->{printer_id} || undef),
        today     => DateTime->today,
      },
    );

    die $result{error} if $result{error};

    $::form->{type}         = 'letter';
    $::form->{formname}     = 'letter';
    $::form->{letternumber} = $letter->letternumber;
    my $attachment_name     = $::form->generate_attachment_filename;

    if ($::instance_conf->get_webdav_documents) {
      my $webdav_file = SL::Webdav::File->new(
        filename => $attachment_name,
        webdav   => SL::Webdav->new(
          type   => 'letter',
          number => $letter->letternumber,
        ),
      );

      $webdav_file->store(file => $result{file_name});
    }

    # set some form defaults for printing webdav copy variables
    if ( $::form->{media} eq 'email') {
      my $mail             = Mailer->new;
      my $signature        = $::myconfig{signature};
      $mail->{$_}          = $params{email}->{$_} for qw(to cc subject message bcc);
      $mail->{from}        = qq|"$::myconfig{name}" <$::myconfig{email}>|;
      $mail->{attachments} = [{ path => $result{file_name},
                                name => $params{email}->{attachment_filename} }];
      $mail->{message}    .=  "\n-- \n$signature";
      $mail->{message}     =~ s/\r//g;
      $mail->{record_id}   =  $letter->id;
      $mail->send;
      unlink $result{file_name};

      flash_later('info', t8('The email has been sent.'));
      $self->redirect_to(action => 'edit', 'letter.id' => $letter->id);

      return 1;
    }

    if (!$::form->{printer_id} || $::form->{media} eq 'screen') {
      $self->send_file($result{file_name}, name => $attachment_name);
      unlink $result{file_name};

      return 1;
    }

    my $printer = SL::DB::Printer->new(id => $::form->{printer_id})->load;
    $printer->print_document(
      copies    => $::form->{copies},
      file_name => $result{file_name},
    );

    unlink $result{file_name};

    flash_later('info', t8('The documents have been sent to the printer \'#1\'.', $printer->printer_description));
    $self->redirect_to(action => 'edit', 'letter.id' => $letter->id, media => 'printer', printer_id => $::form->{printer_id});
    1;
  } or do {
    unlink $result{file_name} if $result{file_name};
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

  my @ids = @{ $::form->{ids} || [] };
  SL::DB::Manager::LetterDraft->delete_all(where => [ id => \@ids ]) if @ids;

  $self->action_add(skip_drafts => 1);
}

sub action_send_email {
  my ($self) = @_;

  $::form->{media} = 'email';
  $self->action_print_letter(email => $::form->{email_form});
}

### internal methods

sub _display {
  my ($self, %params) = @_;

  $::request->{layout}->use_javascript("${_}.js") for qw(ckeditor/ckeditor ckeditor/adapters/jquery kivi.Letter);

  my $letter = $self->letter;

 $params{title} ||= t8('Edit Letter');

  $::form->{type}             = 'letter';   # needed for print_options
  $::form->{vc}               = $letter->is_sales ? 'customer' : 'vendor'; # needs to be for _get_contacts...

  $::request->layout->add_javascripts('customer_or_vendor_selection.js');
  $::request->layout->add_javascripts('edit_part_window.js');

  $::form->{language_id} ||= $params{language_id};
  $::form->{languages}   ||= SL::DB::Manager::Language->get_all_sorted;
  $::form->{printers}      = SL::DB::Manager::Printer->get_all_sorted;

  $self->setup_display_action_bar;
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
                   no_queue        => 1,
                   show_headers    => 1,
                 }),

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

  my @columns  = qw(date subject letternumber customer_id vendor_id contact date);
  my @sortable = qw(date subject letternumber customer_id vendor_id contact date);

  my %column_defs = (
    date                  => { text => t8('Date'),         sub => sub { $_[0]->date_as_date } },
    subject               => { text => t8('Subject'),      sub => sub { $_[0]->subject },
                               obj_link => sub { $self->url_for(action => 'edit', 'letter.id' => $_[0]->id, callback => $self->models->get_callback) }  },
    letternumber          => { text => t8('Letternumber'), sub => sub { $_[0]->letternumber },
                               obj_link => sub { $self->url_for(action => 'edit', 'letter.id' => $_[0]->id, callback => $self->models->get_callback) }  },
    customer_id           => { text => t8('Customer'),      sub => sub { SL::DB::Manager::Customer->find_by_or_create(id => $_[0]->customer_id)->displayable_name }, visible => $self->is_sales },
    vendor_id             => { text => t8('Vendor'),        sub => sub { SL::DB::Manager::Vendor->find_by_or_create(id => $_[0]->vendor_id)->displayable_name }, visible => !$self->is_sales},
    contact               => { text => t8('Contact'),       sub => sub { $_[0]->contact ? $_[0]->contact->full_name : '' } },
  );

  $column_defs{$_}{text} = $sort_columns{$_} for keys %column_defs;

  $report->set_options(
    std_column_visibility => 1,
    controller_class      => 'Letter',
    output_format         => 'HTML',
    title                 => t8('Letters'),
    allow_pdf_export      => 1,
    allow_csv_export      => 1,
  );

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_export_options(qw(list filter is_sales));
  $report->set_options_from_form;

  $self->models->disable_plugin('paginated') if $report->{options}{output_format} =~ /^(pdf|csv)$/i;
  $self->models->add_additional_url_params(is_sales => $self->is_sales);
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

sub load_letter_draft {
  my ($self, %params) = @_;

  return 0 if $params{skip_drafts};

  my $letter_drafts = SL::DB::Manager::LetterDraft->get_all(
    query => [
      SL::DB::Manager::Letter->is_sales_filter($self->is_sales),
    ]
  );

  return unless @$letter_drafts;

  $self->setup_load_letter_draft_action_bar;
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
#     $letter->customer_vendor_id($letter->contact->cp_cv_id);
      # contacts don't have language_id yet
#     $letter->greeting(GenericTranslations->get(
#       translation_type => 'greetings::' . ($letter->contact->cp_gender eq 'f' ? 'female' : 'male'),
#       language_id      => $letter->contact->language_id,
#       allow_fallback   => 1
#     ));
  }

  $self->is_sales($letter->is_sales) if $letter->id;

  $letter;
}

sub init_models {
  my ($self) = @_;

  SL::Controller::Helper::GetModels->new(
    controller   => $self,
    model        => 'Letter',
    query        => [
      SL::DB::Manager::Letter->is_sales_filter($self->is_sales),
    ],
    sorted       => \%sort_columns,
    with_objects => [ 'contact', 'salesman', 'employee' ],
  );
}

sub init_all_employees {
  SL::DB::Manager::Employee->get_all(query => [ deleted => 0 ]);
}

sub init_webdav_objects {
  my ($self) = @_;

  return [] if !$self->letter || !$self->letter->letternumber || !$::instance_conf->get_webdav;

  my $webdav = SL::Webdav->new(
    type     => 'letter',
    number   => $self->letter->letternumber,
  );

  my @all_objects = $webdav->get_all_objects;

  return [ map {
    +{ name => $_->filename,
       type => t8('File'),
       link => File::Spec->catfile($_->full_filedescriptor),
     }
  } @all_objects ];
}

sub init_is_sales {
  die 'is_sales must be set' unless defined $::form->{is_sales};
  $::form->{is_sales};
}

sub check_auth_edit {
  $::auth->assert('sales_letter_edit');
}

sub check_auth_report {
  $::auth->assert('sales_letter_report');
}

sub setup_load_letter_draft_action_bar {
  my ($self, %params) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      link => [
        t8('Skip'),
        link      => $self->url_for(action => 'skip_draft', is_sales => $self->is_sales),
        accesskey => 'enter',
      ],
      action => [
        t8('Delete'),
        submit  => [ '#form', { action => 'delete_drafts' } ],
        checks  => [ [ 'kivi.check_if_entries_selected', '[name="ids[+]"]' ] ],
        confirm => t8('Do you really want to delete this draft?'),
      ],
    );
  }
}

sub setup_display_action_bar {
  my ($self, %params) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Update'),
        submit    => [ '#form', { action => 'Letter/update' } ],
        accesskey => 'enter',
      ],

      combobox => [
        action => [
          t8('Save'),
          submit => [ '#form', { action => 'Letter/save' } ],
        ],
        action => [
          t8('Save Draft'),
          submit => [ '#form', { action => 'Letter/save_letter_draft' } ],
        ],
      ], # end of combobox "Save"

      action => [
        t8('Delete'),
        submit   => [ '#form', { action => 'Letter/delete' } ],
        confirm  => t8('Are you sure you want to delete this letter?'),
        disabled => !$self->letter->id ? t8('The object has not been saved yet.') : undef,
      ],

      combobox => [
        action => [ t8('Export') ],
        action => [
          t8('Print'),
          call     => [ 'kivi.SalesPurchase.show_print_dialog', 'Letter/print_letter' ],
          disabled => !$self->letter->id ? t8('The object has not been saved yet.') : undef,
        ],
        action => [
          t8('E-mail'),
          call     => [ 'kivi.SalesPurchase.show_email_dialog', 'Letter/send_email' ],
          disabled => !$self->letter->id ? t8('The object has not been saved yet.') : undef,
        ],
      ],
    );
  }
}

sub setup_list_action_bar {
  my ($self, %params) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Update'),
        submit    => [ '#search_form', { action => 'Letter/list' } ],
        accesskey => 'enter',
      ],
    );
  }
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::Letter - Letters CRUD and printing

=head1 DESCRIPTION

Simple letter CRUD controller with drafting capabilities.

copy to webdav is crap

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
