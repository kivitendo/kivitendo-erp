package SL::Controller::RecordLinks;

use strict;

use parent qw(SL::Controller::Base);

use List::Util qw(first);

use SL::DB::Helper::Mappings;
use SL::DB::Order;
use SL::DB::DeliveryOrder;
use SL::DB::Invoice;
use SL::DB::Letter;
use SL::DB::PurchaseInvoice;
use SL::DB::RecordLink;
use SL::DB::RequirementSpec;
use SL::DBUtils qw(like);
use SL::DB::ShopOrder;
use SL::JSON;
use SL::Locale::String;
use SL::Presenter::Record qw(grouped_record_list);

use Rose::Object::MakeMethods::Generic
(
  scalar => [ qw(object object_model object_id link_type link_direction link_type_desc) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('check_object_params', only => [ qw(ajax_list ajax_delete ajax_add_select_type ajax_add_filter ajax_add_list ajax_add_do) ]);
__PACKAGE__->run_before('check_link_params',   only => [ qw(                                                           ajax_add_list ajax_add_do) ]);

my %link_type_defaults = (
  filter            => 'type_filter',
  project           => 'globalproject',
  description       => 'transaction_description',
  description_title => t8('Transaction description'),
  date              => 'transdate',
);

my @link_type_specifics = (
  { title => t8('Requirement spec'),        type => 'requirement_spec',        model => 'RequirementSpec', number => 'id', project => 'project', description => 'title', date => undef, filter => 'working_copy_filter', },
  { title => t8('Shop Order'),              type => 'shop_order',              model => 'ShopOrder',       number => 'shop_ordernumber', date => 'order_date', project => undef, },
  { title => t8('Sales quotation'),         type => 'sales_quotation',         model => 'Order',           number => 'quonumber', },
  { title => t8('Sales Order'),             type => 'sales_order',             model => 'Order',           number => 'ordnumber', },
  { title => t8('Sales delivery order'),    type => 'sales_delivery_order',    model => 'DeliveryOrder',   number => 'donumber',  },
  { title => t8('Sales Invoice'),           type => 'invoice',                 model => 'Invoice',         number => 'invnumber', },
  { title => t8('Request for Quotation'),   type => 'request_quotation',       model => 'Order',           number => 'quonumber', },
  { title => t8('Purchase Order'),          type => 'purchase_order',          model => 'Order',           number => 'ordnumber', },
  { title => t8('Purchase delivery order'), type => 'purchase_delivery_order', model => 'DeliveryOrder',   number => 'donumber',  },
  { title => t8('Purchase Invoice'),        type => 'purchase_invoice',        model => 'PurchaseInvoice', number => 'invnumber', },
  { title => t8('Letter'),                  type => 'letter',                  model => 'Letter',          number => 'letternumber', description => 'subject', description_title => t8('Subject'), date => 'date', project => undef },
  { title => t8('Email'),                   type => 'email_journal',           model => 'EmailJournal',    number => 'id', description => 'subject', description_title => t8('Subject'), },
  { title => t8('AR Transaction'),          type => 'ar_transaction',          model => 'Invoice',         number => 'invnumber', },
  { title => t8('AP Transaction'),          type => 'ap_transaction',          model => 'PurchaseInvoice', number => 'invnumber', },
);

my @link_types = map { +{ %link_type_defaults, %{ $_ } } } @link_type_specifics;

#
# actions
#

sub action_ajax_list {
  my ($self) = @_;

  eval {
    my $linked_records = $self->object->linked_records(direction => 'both', recursive => 1, save_path => 1);
    push @{ $linked_records }, $self->object->sepa_export_items if $self->object->can('sepa_export_items');

    my $output         = grouped_record_list(
      $linked_records,
      with_columns      => [ qw(record_link_direction) ],
      edit_record_links => 1,
      object_model      => $self->object_model,
      object_id         => $self->object_id,
    );
    $self->render(\$output, { layout => 0, process => 0 });

    1;
  } or do {
    $self->render('generic/error', { layout => 0 }, label_error => $@);
  };
}

sub action_ajax_delete {
  my ($self) = @_;

  foreach my $str (@{ $::form->{record_links_delete} || [] }) {
    my ($from_table, $from_id, $to_table, $to_id) = split m/__/, $str, 4;
    $from_id *= 1;
    $to_id   *= 1;

    next if !$from_table || !$from_id || !$to_table || !$to_id;

    SL::DB::Manager::RecordLink->delete_all(where => [
      from_table => $from_table,
      from_id    => $from_id,
      to_table   => $to_table,
      to_id      => $to_id,
    ]);
  }

  $self->action_ajax_list;
}

sub action_ajax_add_filter {
  my ($self) = @_;

  my $presenter = $self->presenter;

  my @link_type_select = map { [ $_->{type}, $_->{title} ] } @link_types;
  my @projects         = map { [ $_->id, $_->presenter->project(display => 'inline', style => 'both', no_link => 1) ] } @{ SL::DB::Manager::Project->get_all_sorted };
  my $is_sales         = $self->object->can('customer_id') && $self->object->customer_id;

  $self->render(
    'record_links/add_filter',
    { layout          => 0 },
    is_sales          => $is_sales,
    DEFAULT_LINK_TYPE => $is_sales ? 'sales_quotation' : 'request_quotation',
    LINK_TYPES        => \@link_type_select,
    PROJECTS          => \@projects,
  );
}

sub action_ajax_add_list {
  my ($self) = @_;

  my $manager     = 'SL::DB::Manager::' . $self->link_type_desc->{model};
  my $vc          = $self->link_type =~ m/shop|sales_|^invoice|requirement_spec|letter|^ar_/ ? 'customer' : 'vendor';
  my $project     = $self->link_type_desc->{project};
  my $project_id  = "${project}_id";
  my $description = $self->link_type_desc->{description};
  my $filter      = $self->link_type_desc->{filter};

  my @where = $filter && $manager->can($filter) ? $manager->$filter($self->link_type) : ();
  push @where, ("${vc}.${vc}number"     => { ilike => like($::form->{vc_number}) })               if $::form->{vc_number};
  push @where, ("${vc}.name"            => { ilike => like($::form->{vc_name}) })                 if $::form->{vc_name};
  push @where, ($description            => { ilike => like($::form->{transaction_description}) }) if $::form->{transaction_description};
  push @where, ($project_id             => $::form->{globalproject_id})                           if $::form->{globalproject_id} && $manager->can($project_id);

  my @with_objects = ($vc);
  push @with_objects, $project if $manager->can($project_id);

  # show the newest records first (should be better for 80% of the cases TODO sortable click
  my $objects = $manager->get_all_sorted(where => \@where, with_objects => \@with_objects, sort_by => 'itime',  sort_dir => 'ASC');
  my $output  = $self->render(
    'record_links/add_list',
    { output => 0 },
    OBJECTS            => $objects,
    vc                 => $vc,
    number_column      => $self->link_type_desc->{number},
    description_column => $description,
    description_title  => $self->link_type_desc->{description_title},
    project_column     => $project,
    date_column        => $self->link_type_desc->{date},
  );

  my %result = ( count => scalar(@{ $objects }), html => $output );

  $self->render(\to_json(\%result), { type => 'json', process => 0 });
}

sub action_ajax_add_do {
  my ($self, %params) = @_;

  my $object_side = $self->link_direction eq 'from' ? 'from' : 'to';
  my $link_side   = $object_side          eq 'from' ? 'to'   : 'from';
  my $link_table  = SL::DB::Helper::Mappings::get_table_for_package($self->link_type_desc->{model});

  foreach my $link_id (@{ $::form->{link_id} || [] }) {
    # Check for existing reverse connections in order to avoid loops.
    my @props = (
      "${link_side}_table"   => $self->object->meta->table,
      "${link_side}_id"      => $self->object_id,
      "${object_side}_table" => $link_table,
      "${object_side}_id"    => $link_id,
    );

    my $existing = SL::DB::Manager::RecordLink->get_all(where => \@props, limit => 1)->[0];
    next if $existing;

    # Check for existing connections in order to avoid duplicates.
    @props = (
      "${object_side}_table" => $self->object->meta->table,
      "${object_side}_id"    => $self->object_id,
      "${link_side}_table"   => $link_table,
      "${link_side}_id"      => $link_id,
    );

    $existing = SL::DB::Manager::RecordLink->get_all(where => \@props, limit => 1)->[0];

    SL::DB::RecordLink->new(@props)->save if !$existing;
  }

  $self->action_ajax_list;
}


#
# filters
#

sub check_object_params {
  my ($self) = @_;

  my %models = map { ($_->{model} => 1 ) } @link_types;

  $self->object_id(   $::form->{object_id});
  $self->object_model($::form->{object_model});

  die "Invalid object_model or object_id" if !$self->object_id || !$models{$self->object_model};

  my $model = 'SL::DB::' . $self->object_model;
  $self->object($model->new(id => $self->object_id)->load || die "Record not found");

  return 1;
}

sub check_link_params {
  my ($self) = @_;

  $self->link_type(     $::form->{link_type});
  $self->link_type_desc((first { $_->{type} eq $::form->{link_type} } @link_types)                || die "Invalid link_type");
  $self->link_direction($::form->{link_direction} =~ m/^(?:from|to)$/ ? $::form->{link_direction} :  die "Invalid link_direction");

  return 1;
}

sub check_auth {
  $::auth->assert('record_links');
}

1;
