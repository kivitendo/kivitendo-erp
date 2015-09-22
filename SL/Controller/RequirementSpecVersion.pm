package SL::Controller::RequirementSpecVersion;

use strict;

use parent qw(SL::Controller::Base);

use Carp;
use List::MoreUtils qw(any);

use SL::DB::Customer;
use SL::DB::Project;
use SL::DB::RequirementSpec;
use SL::DB::RequirementSpecVersion;
use SL::Helper::Flash;
use SL::Locale::String;

use Rose::Object::MakeMethods::Generic
(
  'scalar --get_set_init' => [ qw(requirement_spec version) ],
);

__PACKAGE__->run_before('check_auth');

#
# actions
#

sub action_list {
  my ($self, %params) = @_;

  $self->render('requirement_spec_version/list', { layout => 0 });
}

sub action_new {
  my ($self) = @_;

  $self->version(SL::DB::RequirementSpecVersion->new);

  my $previous_version = $self->requirement_spec->highest_version;

  if (!$previous_version) {
    $self->version->description(t8('Initial version.'));

  } else {
    my %differences = $self->calculate_differences(current => $self->requirement_spec, previous => $previous_version);

    my @lines;

    my $fb_diff = $differences{function_blocks};
    push @lines, t8('Added sections and function blocks: #1',   $::locale->language_join([ map { $_->fb_number         } @{ $fb_diff->{additions} } ])) if @{ $fb_diff->{additions} };
    push @lines, t8('Changed sections and function blocks: #1', $::locale->language_join([ map { $_->fb_number         } @{ $fb_diff->{changes}   } ])) if @{ $fb_diff->{changes}   };
    push @lines, t8('Removed sections and function blocks: #1', $::locale->language_join([ map { $_->fb_number         } @{ $fb_diff->{removals}  } ])) if @{ $fb_diff->{removals}  };

    my $tb_diff = $differences{text_blocks};
    push @lines, t8('Added text blocks: #1',                    $::locale->language_join([ map { '"' . $_->title . '"' } @{ $tb_diff->{additions} } ])) if @{ $tb_diff->{additions} };
    push @lines, t8('Changed text blocks: #1',                  $::locale->language_join([ map { '"' . $_->title . '"' } @{ $tb_diff->{changes}   } ])) if @{ $tb_diff->{changes}   };
    push @lines, t8('Removed text blocks: #1',                  $::locale->language_join([ map { '"' . $_->title . '"' } @{ $tb_diff->{removals}  } ])) if @{ $tb_diff->{removals}  };

    $self->version->description(@lines ? join("\n", @lines) : t8('No changes since previous version.'));
  }

  $self->render('requirement_spec_version/new', { layout => 0 });
}

sub action_create {
  my ($self, %params) = @_;

  my %attributes = %{ delete($::form->{rs_version}) || {} };
  my @errors     = SL::DB::RequirementSpecVersion->new(%attributes, version_number => 1)->validate;

  return $self->js->error(@errors)->render if @errors;

  my $db     = $self->requirement_spec->db;
  my @result = $self->requirement_spec->create_version(%attributes);

  if (!@result) {
    $::lxdebug->message(LXDebug::WARN(), "Error: " . $db->error);
    return $self->js->error($::locale->text('Saving failed. Error message from the database: #1'), $db->error)->render;
  }

  $self->version($result[0]);
  my $version_info_html = $self->render('requirement_spec/_version',     { output => 0 }, requirement_spec => $self->requirement_spec);
  my $version_list_html = $self->render('requirement_spec_version/list', { output => 0 });

  $self->js
    ->html('#requirement_spec_version', $version_info_html)
    ->html('#versioned_copies_list',    $version_list_html)
    ->dialog->close('#jqueryui_popup_dialog')
    ->render;
}

#
# filters
#

sub check_auth {
  my ($self, %params) = @_;
  $::auth->assert('requirement_spec_edit');
}

#
# helpers
#

sub init_requirement_spec {
  my ($self) = @_;
  $self->requirement_spec(SL::DB::RequirementSpec->new(id => $::form->{requirement_spec_id})->load) if $::form->{requirement_spec_id};
}

sub init_version {
  my ($self) = @_;
  $self->version(SL::DB::RequirementSpecVersion->new(id => $::form->{id})->load) if $::form->{id};
}

sub has_item_changed {
  my ($previous, $current) = @_;
  croak "Missing previous/current" if !$previous || !$current;

  return 1 if any { ($previous->$_ || '') ne ($current->$_ || '') } qw(item_type fb_number title description complexity_id risk_id);
  return 0 if !$current->parent_id;
  return $previous->parent->fb_number ne $current->parent->fb_number;
}

sub has_text_block_changed {
  my ($previous, $current) = @_;
  croak "Missing previous/current" if !$previous || !$current;
  return any { ($previous->$_ || '') ne ($current->$_ || '') } qw(title text);
}

sub compare_items {
  return -1 if ($a->item_type eq 'section') && ($b->item_type ne 'section');
  return +1 if ($a->item_type ne 'section') && ($b->item_type eq 'section');
  return $a->fb_number cmp $b->fb_number;
}

sub calculate_differences {
  my ($self, %params) = @_;

  my %differences = (
    function_blocks => {
      additions => [],
      changes   => [],
      removals  => [],
    },
    text_blocks => {
      additions => [],
      changes   => [],
      removals  => [],
    },
  );

  return %differences if !$params{previous} || !$params{current};

  my @previous_items                         = sort compare_items @{ $params{previous}->items };
  my @current_items                          = sort compare_items @{ $params{current}->items  };

  my @previous_text_blocks                   = sort { lc $a->title cmp lc $b->title } @{ $params{previous}->text_blocks };
  my @current_text_blocks                    = sort { lc $a->title cmp lc $b->title } @{ $params{current}->text_blocks  };

  my %previous_items_map                     = map { $_->fb_number => $_ } @previous_items;
  my %current_items_map                      = map { $_->fb_number => $_ } @current_items;

  my %previous_text_blocks_map               = map { $_->title     => $_ } @previous_text_blocks;
  my %current_text_blocks_map                = map { $_->title     => $_ } @current_text_blocks;

  $differences{function_blocks}->{additions} = [ grep { !$previous_items_map{ $_->fb_number }                                                                         } @current_items        ];
  $differences{function_blocks}->{removals}  = [ grep { !$current_items_map{  $_->fb_number }                                                                         } @previous_items       ];
  $differences{function_blocks}->{changes}   = [ grep {  $previous_items_map{ $_->fb_number }       && has_item_changed($previous_items_map{ $_->fb_number }, $_)     } @current_items        ];

  $differences{text_blocks}->{additions}     = [ grep { !$previous_text_blocks_map{ $_->title }                                                                       } @current_text_blocks  ];
  $differences{text_blocks}->{removals}      = [ grep { !$current_text_blocks_map{  $_->title }                                                                       } @previous_text_blocks ];
  $differences{text_blocks}->{changes}       = [ grep {  $previous_text_blocks_map{ $_->title } && has_text_block_changed($previous_text_blocks_map{ $_->title }, $_) } @current_text_blocks  ];

  return %differences;
}

1;
