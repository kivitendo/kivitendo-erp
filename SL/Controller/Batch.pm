package SL::Controller::Batch;

use strict;
use parent qw(SL::Controller::Base);

use SL::DB::Batch;
use SL::Helper::Flash;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw( batch employee part vendor ) ],
);

my $may_edit = 1;

__PACKAGE__->run_before( '_create', except => [ 'search', 'list' ] );
__PACKAGE__->run_before( '_load', only => [ 'delete', 'edit', 'save', 'save_and_close' ] );
__PACKAGE__->run_before( '_copy', only => [ 'save', 'save_and_close' ] );
__PACKAGE__->run_before( '_forward_tags_hidden', only => [ 'edit', 'list' ] );
__PACKAGE__->run_before( '_forward_tags_redirected', except => [ 'edit', 'list', 'search' ] );
__PACKAGE__->run_before( '_pre_render', only => [ 'add', 'edit' ] );

#
# Actions
#

# adds a new batch
sub action_add {
  my( $self, $form, $locale ) = ( shift, $::form, $::locale );
  $self->batch->batchdate( DateTime->now_local() );
  $self->_setup_form_action_bar;
  $self->render(
    'batch/form',
    title => $locale->text( 'Add Batch' )
  );
}

# deletes an existing batch
sub action_delete {
  my( $self, $form, $locale ) = ( shift, $::form, $::locale );
  my( $action, @errors ) = ( '', () );
  @errors = $self->batch->has_children
         or $self->batch->delete || push( @errors, $self->batch->db->error );
  if( scalar @errors ) {
    flash_later( 'error', @errors );
    $action = 'edit';
  } else {
    flash_later( 'info', $locale->text( 'The batch has been deleted.' ) );
    $action = $self->{ callback };
  }
  $self->_redirect_to( $action );
}

# edits an existing batch
sub action_edit {
  my( $self, $form, $locale ) = ( shift, $::form, $::locale );
  $self->_setup_form_action_bar;
  $self->render(
    'batch/form',
    title => $locale->text( 'Edit Batch')
  );
}

# lists the filtred and sorted batches
sub action_list {
  my( $self, $form, $locale ) = ( shift, $::form, $::locale );

  $form->{ filter_rows }->{ producer_id } && $self->vendor( SL::DB::Vendor->new( id => $form->{ filter_rows }->{ producer_id } )->load );
  $form->{ filter_rows }->{ part_id } && $self->part( SL::DB::Part->new( id => $form->{ filter_rows }->{ part_id } )->load );
  $form->{ filter_rows }->{ employee_id } && $self->employee( SL::DB::Employee->new( id => $form->{ filter_rows }->{ employee_id } )->load );

  $self->{ columns } = [
    { key => 'producer'   , label => 'Producer' },
    { key => 'part'       , label => 'Part' },
    { key => 'batchnumber', label => 'Batch Number' },
    { key => 'batchdate'  , label => 'Batch Date' },
    { key => 'location'   , label => 'Batch Location' },
    { key => 'process'    , label => 'Batch Process' },
    { key => 'insertdate' , label => 'Insert Date' },
    { key => 'changedate' , label => 'Updated' },
    { key => 'employee'   , label => 'Employee' }
  ];

  $self->{ filter } = join( '&',
    map {'filter_columns.' . $_ . '=' . $self->{ filter_columns }->{ $_ } } keys %{ $self->{ filter_columns } }
  );
  my @filter = $self->_filter;
  @{ $self->{ all_batches } } = @{ SL::DB::Manager::Batch->get_all( where => \@filter ) }
    and $self->_sort( $self->{ sort_column } );

  $self->_setup_list_action_bar;
  $self->render(
    'batch/list',
    title => $locale->text( 'Batches' )
  );
}

# saves a new or edited batch
sub action_save {
  my $self = shift;
  $self->_save;
  $self->_redirect_to( $self->{ callback } ne 'add' ? 'edit' : 'add' );
}

# saves a new or edited batch and closes the frame
sub action_save_and_close {
  my $self = shift;
  $self->_save;
  $self->_redirect_to( $self->{ callback } );
}

# filter the batches and their fields to list
sub action_search {
  my( $self, $locale ) = ( shift, $::locale );
  $self->{ callback } = 'list';
  $self->{ sort_column } = 'producer';
  %{ $self->{ filter_columns } } = ();
  %{ $self->{ filter_rows } } = ();
  $self->{ all_employees } = SL::DB::Manager::Employee->get_all( sort_by => 'name' );
  $self->_setup_search_action_bar;
  $self->render(
    'batch/search',
    title => $locale->text( 'Batches' )
  );
}

#
# Helpers
#

sub _copy {
  my( $self, $form ) = ( shift, $::form );
  foreach( keys %{ $form->{ batch } } ) {
    $self->batch->can( "$_" ) && $self->batch->$_( $form->{ batch }->{ $_ } );
  }
}

sub _create {
  my $self = shift;
  $self->batch( SL::DB::Batch->new );
}

sub _filter {
  my( $self, $form ) = ( shift, $::form );
  my @filter = ( deleted => 'false' );
  foreach( keys %{ $self->{ filter_rows } } ) {
    if( $self->{ filter_rows }->{ $_ } ) {
      $_ =~ m/^.*?_from$/ and $_ =~ s/^(.*?)_from$/$1/
        and push( @filter, ( $_ => { ge => $self->{ filter_rows }->{ $_ . '_from' } } ) )
        and $self->{ filter } .= '&filter_rows.' . $_ . '_from' . '=' . $form->escape( $self->{ filter_rows }->{ $_ . '_from' } )
      or $_ =~ m/^.*?_to$/ and $_ =~ s/^(.*?)_to$/$1/
        and push( @filter, ( $_ => { le => $self->{ filter_rows }->{ $_ . '_to' } } ) )
        and $self->{ filter } .= '&filter_rows.' . $_ . '_to' . '=' . $form->escape( $self->{ filter_rows }->{ $_ . '_to' } )
      or $_ =~ m/^.*?_id$/
        and push( @filter, ( $_ => $self->{ filter_rows }->{ $_ } ) )
        and $self->{ filter } .= '&filter_rows.' . $_ . '=' . $form->escape( $self->{ filter_rows }->{ $_ } )
      or push( @filter, ( $_ => { like => $self->{ filter_rows }->{ $_ } } ) )
        and $self->{ filter } .= '&filter_rows.' . $_ . '=' . $form->escape( $self->{ filter_rows }->{ $_ } )
      ;
    }
  }
  return @filter;
}

sub _forward_tags_hidden {
  my( $self, $form ) = ( shift, $::form );
  $self->{ callback } = $form->{ callback } || 'add';
  $self->{ sort_column } = $form->{ sort_column } || 'producer';
  %{ $self->{ filter_columns } } = $form->{ filter_columns } ? %{ $form->{ filter_columns } } : ();
  %{ $self->{ filter_rows } } = $form->{ filter_rows } ? %{ $form->{ filter_rows } } : ();
}

sub _forward_tags_redirected {
  my( $self, $form ) = ( shift, $::form );
  $self->{ callback } = $form->{ callback } || 'add';
  $self->{ sort_column } = $form->{ sort_column } || 'producer';
  %{ $self->{ filter_columns } } = $form->{ filter_columns } ? split( /,/, $form->{ filter_columns } ) : ();
  %{ $self->{ filter_rows } } = $form->{ filter_rows } ? split( /,/, $form->{ filter_rows } ) : ();
}

sub _load {
  my( $self, $form ) = ( shift, $::form );
  $self->batch->id( $form->{ id } ) && $self->batch->load if $form->{ id };
}

sub _pre_render {
  my $self = shift;
  $self->{ all_employees } = SL::DB::Manager::Employee->get_all(
    where => [ or => [
      id      => $self->batch->employee_id,
      deleted => 0
    ] ],
    sort_by => 'name'
  );
}

sub _redirect_to {
  my( $self, $action ) = @_;
  $self->SUPER::redirect_to(
    script => 'contoller.pl',
    action => $action,
    id     => $self->batch->id,
    callback => $self->{ callback },
    sort_column => $self->{ sort_column },
    filter_columns => $self->{ filter_columns },
    filter_rows => $self->{ filter_rows }
  );
}

sub _save {
  my( $self, $form, $locale ) = ( shift, $::form, $::locale );
  my @errors = ();
  @errors = $self->batch->validate
         or $self->batch->save || push( @errors, $self->batch->db->error );
  if( scalar @errors ) {
    flash_later( 'error', @errors );
  } else {
    flash_later( 'info', $locale->text( 'The batch has been saved.' ) );
  }
}

sub _sort {
  my( $self, $column ) = @_;
  my (%a,%b);
  $column eq 'producer' and @{ $self->{ all_batches } } = sort {
    $a->producer->name cmp $b->producer->name
    || $a->part->partnumber cmp $b->part->partnumber
    || $a->batchnumber cmp $b->batchnumber
  } @{ $self->{ all_batches } }
  or $column eq 'part' and @{ $self->{ all_batches } } = sort {
    $a->part->partnumber cmp $b->part->partnumber
    || $a->batchnumber cmp $b->batchnumber
  } @{ $self->{ all_batches } }
  or $column eq 'batchnumber' and @{ $self->{ all_batches } } = sort {
    $a->batchnumber cmp $b->batchnumber
  } @{ $self->{ all_batches } }
  or $column eq 'batchdate' and @{ $self->{ all_batches } } = sort {
    $a->batchdate cmp $b->batchdate
    || $a->location cmp $b->location
    || $a->process cmp $b->process
  } @{ $self->{ all_batches } }
  or $column eq 'location' and @{ $self->{ all_batches } } = sort {
    $a->location cmp $b->location
    || $a->process cmp $b->process
  } @{ $self->{ all_batches } }
  or $column eq 'process' and @{ $self->{ all_batches } } = sort {
    $a->process cmp $b->process
  } @{ $self->{ all_batches } }
  or $column eq 'insertdate' and @{ $self->{ all_batches } } = sort {
    $a->itime cmp $b->itime
    || $a->mtime cmp $b->mtime
    || $a->employee->name cmp $b->employee->name
  } @{ $self->{ all_batches } }
  or $column eq 'changedate' and @{ $self->{ all_batches } } = sort {
    $a->mtime cmp $b->mtime
    || $a->employee->name cmp $b->employee->name
  } @{ $self->{ all_batches } }
  or $column eq 'employee' and @{ $self->{ all_batches } } = sort {
    $a->employee->name cmp $b->employee->name
  } @{ $self->{ all_batches } }
  ;
}

#
# Actionbars
#

sub _setup_form_action_bar {
  my( $self, $locale ) = ( shift, $::locale );
  for my $bar ($::request->layout->get( 'actionbar' )) {
    $bar->add(
      combobox => [
        action => [
          $locale->text( 'Save' ),
          submit    => [ '#batch_form', {
            action => 'Batch/save',
            sort_column => $self->{ sort_column },
            filter_columns => join( ',', %{ $self->{ filter_columns } } ),
            filter_rows => join( ',', %{ $self->{ filter_rows } } )
          } ],
          disabled  => !$may_edit ? $locale->text( 'You do not have the permissions to access this function.' )
                     : undef,
          accesskey => 'enter'
        ],
        action => [
          $locale->text( 'Save and Close' ),
          submit => [ '#batch_form', {
            action => 'Batch/save_and_close',
            sort_column => $self->{ sort_column },
            filter_columns => join( ',', %{ $self->{ filter_columns } } ),
            filter_rows => join( ',', %{ $self->{ filter_rows } } )
          } ],
          disabled  => !$may_edit ? $locale->text( 'You do not have the permissions to access this function.' )
                     : undef
        ]
      ], # end of combobox "Save"
      action => [
        $locale->text( 'Delete' ),
        submit   => [ '#batch_form', {
          action => 'Batch/delete',
          sort_column => $self->{ sort_column },
          filter_columns => join( ',', %{ $self->{ filter_columns } } ),
          filter_rows => join( ',', %{ $self->{ filter_rows } } )
         } ],
        confirm  => $locale->text( 'Do you really want to delete this object?' ),
        disabled => !$may_edit                 ? $locale->text( 'You do not have the permissions to access this function.' )
                  : !$self->batch->id          ? $locale->text( 'This object has not been saved yet.' )
                  : $self->batch->has_children ? $locale->text( 'This object has already been used.' )
                  : undef
      ],
#      action => [
#        $::locale->text( 'History' ),
#        call     => [ 'kivi.Batch.showHistoryWindow', $self->batch->id ],
#        disabled => !$may_edit        ? $locale->text( 'You do not have the permissions to access this function.' )
#                  : !$self->batch->id ? $locale->text( 'This object has not been saved yet.' )
#                  : undef,
#      ]
    );
  }
}

sub _setup_list_action_bar {
  my( $self, $locale ) = ( shift, $::locale );
  for my $bar ($::request->layout->get( 'actionbar' ) ) {
    $bar->add(
      action => [
        $locale->text( 'Add' ),
        submit    => [ '#batch_list', {
          action => 'Batch/add',
          callback => $self->{ callback },
          sort_column => $self->{ sort_column },
          filter_columns => join( ',', %{ $self->{ filter_columns } } ),
          filter_rows => join( ',', %{ $self->{ filter_rows } } )
        } ],
        accesskey => 'enter'
      ]
    );
  }
}

sub _setup_search_action_bar {
  my( $self, $locale ) = ( shift, $::locale );
  for my $bar ($::request->layout->get( 'actionbar' ) ) {
    $bar->add(
      action => [
        $locale->text( 'Search' ),
        submit    => [ '#batch_search', {
          action => 'Batch/list',
          callback => $self->{ callback },
        } ],
        accesskey => 'enter'
      ]
    );
  }
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::Batch - Batch CRUD controller

=head1 DESCRIPTION

Implements the URL Actions.
They loads the requesting form and database objects if needed.
Finally prepares and calls the responding form or redirects to the according action.
The output list is realised by a HTML-Template to avoid "bin/mozilla".

=head1 URL ACTIONS

=over 4

=item C<action_add>

Adds a new batch.

=item C<action_delete

Deletes an existing batch.

=item C<action_edit>

Edits an existing batch.

=item C<action_list>

Lists the filtred and sorted batches.

=item C<action_save>

Saves a new or edited batch and responds the Edit-Form.

=item C<action_save_and_close>

Saves a new or edited batch and closes the frame.

=item C<action_search>

Filters the batches and their fields to list.

=back

=head1 HELPER FUNCTIONS

=over 4

=item C<_copy>

Copies the fields of a batch from the requesting form to the rose-object.

=item C<_create>

Creates a new batch-rose-object.

=item C<_filter>

Returns the filter of the batches-query and sets those of the responding form.

=item C<_forward_tags_hidden>

Sets the searche and sort criteria for the callback of the responding form.

=item C<_forward_tags_redirected>

Sets the searche and sort criteria for the callback of the redirected action.

=item C<_load>

Loads the batch-rose-object at the redirected action.

=item C<_pre_render>

Prepares the responding form.

=item C<_redirect_to>

Redirects to the passed action.

=item C<_save>

Saves a new or edited batch.

=item C<_sort>

Sorts the loaded batches by the key of the requesting form.

=back

=head1 ACTION BARS

=over 4

_setup_form_action_bar
_setup_list_action_bar
_setup_search_action_bar

=back

=head1 TODO

=over 4

=item *

The action "delete" still deletes physically.
To mark the table-entries as deletet could be advantageous.

=item *

Actually the filter- and sort-criteria for the callbacked list are passed through the responds.
They should be cached and restored by the list.

=item *

The History-Button of the form_action_bar isn,t yet implemented

=item *

The rights aren,t yet implemented. They should be "read", "insert", "update", "delete".

=back

=head1 AUTHOR

Rolf Flühmann E<lt>rolf.fluehmann@revamp-it.chE<gt>,
ROlf Flühmann E<lt>rolf_fluehmann@gmx.chE<gt>

=cut
