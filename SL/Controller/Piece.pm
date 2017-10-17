package SL::Controller::Piece;

use strict;
use parent qw(SL::Controller::Base);

use SL::DB::Batch;
use SL::DB::Piece;
use SL::Helper::Flash;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw( batch bin delivery_orders employee part piece vendor ) ],
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

# add a new piece
sub action_add {
  my( $self, $form, $locale ) = ( shift, $::form, $::locale );
  $self->_setup_form_action_bar;
  $self->render(
    'piece/form',
    title => $locale->text( 'Add Piece' )
  );
}

# delete an existing piece
sub action_delete {
  my( $self, $form, $locale ) = ( shift, $::form, $::locale );
  my( $action, @errors ) = ( '', () );
  @errors = $self->piece->delete || push( @errors, $self->piece->db->error );
  if( scalar @errors ) {
    flash_later( 'error', @errors );
    $action = 'edit';
  } else {
    flash_later( 'info', $locale->text( 'The piece has been deleted.' ) );
    $action = $self->{ callback };
  }
  $self->_redirect_to( $action );
}

# edit an existing piece
sub action_edit {
  my( $self, $form, $locale ) = ( shift, $::form, $::locale );
  $self->_setup_form_action_bar;
  $self->render(
    'piece/form',
    title => $locale->text( 'Edit Piece')
  );
}

# list the filtred and sorted pieces
sub action_list {
  my( $self, $form, $locale ) = ( shift, $::form, $::locale );

  $form->{ filter_rows }->{ producer_id } && $self->vendor( SL::DB::Vendor->new( id => $form->{ filter_rows }->{ producer_id } )->load );
  $form->{ filter_rows }->{ part_id } && $self->part( SL::DB::Part->new( id => $form->{ filter_rows }->{ part_id } )->load );
  $form->{ filter_rows }->{ batch_id } && $self->batch( SL::DB::Batch->new( id => $form->{ filter_rows }->{ batch_id } )->load );
  $form->{ filter_rows }->{ employee_id_id } && $self->employee( SL::DB::Employee->new( id => $form->{ filter_rows }->{ employee_in_id } )->load );
  $form->{ filter_rows }->{ employee_out_id } && $self->employee( SL::DB::Employee->new( id => $form->{ filter_rows }->{ employee_out_id } )->load );

  $self->{ columns } = [
    { key => 'producer'     , label => 'Producer' },
    { key => 'part'         , label => 'Part' },
    { key => 'batch'        , label => 'Batch' },
    { key => 'serialnumber' , label => 'Serial Number' },
    { key => 'weight'       , label => 'Weight' },
    { key => 'delivery_in'  , label => 'Incoming Delivery Order' },
    { key => 'bin'          , label => 'Bin' },
    { key => 'delivery_out' , label => 'Outgoing Delivery Order' },
    { key => 'insertdate'   , label => 'Insert Date' },
    { key => 'changedate'   , label => 'Updated' },
    { key => 'employee'     , label => 'Employee' }
  ];

  $self->{ filter } = join( '&',
    map {'filter_columns.' . $_ . '=' . $self->{ filter_columns }->{ $_ } } keys %{ $self->{ filter_columns } }
  );
  my @filter = $self->_filter;
  @{ $self->{ all_pieces } } = @{ SL::DB::Manager::Piece->get_all( where => \@filter ) }
    and $self->_sort( $self->{ sort_column } );

  $self->_setup_list_action_bar;
  $self->render(
    'piece/list',
    title => $locale->text( 'Pieces' )
  );
}

# save a new or edited piece
sub action_save {
  my $self = shift;
  $self->_save;
  $self->_redirect_to( $self->{ callback } ne 'add' ? 'edit' : 'add' );
}

# save a new or edited piece and close the frame
sub action_save_and_close {
  my $self = shift;
  $self->_save;
  $self->_redirect_to( $self->{ callback } );
}

# filter the pieces to list
sub action_search {
  my( $self, $locale ) = ( shift, $::locale );
  $self->{ callback } = 'list';
  $self->{ sort_column } = 'producer';
  %{ $self->{ filter_columns } } = ();
  %{ $self->{ filter_rows } } = ();
  $self->{ all_employees } = SL::DB::Manager::Employee->get_all( sort_by => 'name' );
  $self->_setup_search_action_bar;
  $self->render(
    'piece/search',
    title => $locale->text( 'Pieces' )
  );
}

#
# Helpers
#

sub _copy {
  my( $self, $form ) = ( shift, $::form );
  foreach( keys %{ $form->{ piece } } ) {
    $self->piece->can( "$_" ) && $self->piece->$_( $form->{ piece }->{ $_ } );
  }
}

sub _create {
  my $self = shift;
  $self->piece( SL::DB::Piece->new );
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
  $self->piece->id( $form->{ id } ) && $self->piece->load if $form->{ id };
}

sub _pre_render {
  my $self = shift;
  $self->{ all_batches } = SL::DB::Manager::Batch->get_all(
    where => [ or => [
      id      => $self->piece->batch_id,
      deleted => 0
    ] ],
    sort_by => 'batchnumber'
  );
  unshift( $self->{ all_batches }, undef );
  $self->{ all_bins } = SL::DB::Manager::Bin->get_all( sort_by => 'description' );
  unshift( $self->{ all_bins }, undef );
  $self->{ all_deliveries } = SL::DB::Manager::DeliveryOrder->get_all( sort_by => 'donumber' );
  $self->{ all_employees } = SL::DB::Manager::Employee->get_all(
    where => [ or => [
      id      => $self->piece->employee_id,
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
    id     => $self->piece->id,
    callback => $self->{ callback },
    sort_column => $self->{ sort_column },
    filter_columns => $self->{ filter_columns },
    filter_rows => $self->{ filter_rows }
  );
}

sub _save {
  my( $self, $form, $locale ) = ( shift, $::form, $::locale );
  $self->piece->undefine;
  my @errors = ();
  @errors = $self->piece->validate
         or $self->piece->save || push( @errors, $self->piece->db->error );
  if( scalar @errors ) {
    flash_later( 'error', @errors );
  } else {
    flash_later( 'info', $locale->text( 'The piece has been saved.' ) );
  }
}

sub _sort {
  my( $self, $column ) = @_;
  my (%a,%b);
  $column eq 'producer' and @{ $self->{ all_pieces } } = sort {
    $a->producer->name cmp $b->producer->name
    || $a->part->partnumber cmp $b->part->partnumber
    || $a->batch->batchnumber cmp $b->batch->batchnumber
    || $a->serialnumber cmp $b->serialnumber
  } @{ $self->{ all_pieces } }
  or $column eq 'part' and @{ $self->{ all_pieces } } = sort {
    $a->part->partnumber cmp $b->part->partnumber
    || $a->batch->batchnumber cmp $b->batch->batchnumber
    || $a->serialnumber cmp $b->serialnumber
  } @{ $self->{ all_pieces } }
  or $column eq 'batch' and @{ $self->{ all_pieces } } = sort {
    $a->batch->batchnumber cmp $b->batch->batchnumber
    || $a->serialnumber cmp $b->serialnumber
  } @{ $self->{ all_pieces } }
  or $column eq 'piecenumber' and @{ $self->{ all_pieces } } = sort {
    $a->serialnumber cmp $b->serialnumber
  } @{ $self->{ all_pieces } }
  or $column eq 'weight' and @{ $self->{ all_pieces } } = sort {
    $a->weight cmp $b->weight
  } @{ $self->{ all_pieces } }
  or $column eq 'delivery_in' and @{ $self->{ all_pieces } } = sort {
    $a->delivery->donumber cmp $b->delivery_orders->donumber
  } @{ $self->{ all_pieces } }
  or $column eq 'bin' and @{ $self->{ all_pieces } } = sort {
    $a->bin->description cmp $b->bin->description
  } @{ $self->{ all_pieces } }
  or $column eq 'insertdate' and @{ $self->{ all_pieces } } = sort {
    $a->itime cmp $b->itime
    || $a->mtime cmp $b->mtime
    || $a->employee->name cmp $b->employee->name
  } @{ $self->{ all_pieces } }
  or $column eq 'changedate' and @{ $self->{ all_pieces } } = sort {
    $a->mtime cmp $b->mtime
    || $a->employee->name cmp $b->employee->name
  } @{ $self->{ all_pieces } }
  or $column eq 'employee' and @{ $self->{ all_pieces } } = sort {
    $a->employee->name cmp $b->employee->name
  } @{ $self->{ all_pieces } }
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
          submit    => [ '#piece_form', {
            action => 'Piece/save',
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
          submit => [ '#piece_form', {
            action => 'Piece/save_and_close',
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
        submit   => [ '#piece_form', {
          action => 'Piece/delete',
          sort_column => $self->{ sort_column },
          filter_columns => join( ',', %{ $self->{ filter_columns } } ),
          filter_rows => join( ',', %{ $self->{ filter_rows } } )
         } ],
        confirm  => $locale->text( 'Do you really want to delete this object?' ),
        disabled => !$may_edit                 ? $locale->text( 'You do not have the permissions to access this function.' )
                  : !$self->piece->id          ? $locale->text( 'This object has not been saved yet.' )
                  : undef
      ],
#      action => [
#        $::locale->text( 'History' ),
#        call     => [ 'kivi.Batch.showHistoryWindow', $self->piece->id ],
#        disabled => !$may_edit        ? $locale->text( 'You do not have the permissions to access this function.' )
#                  : !$self->piece->id ? $locale->text( 'This object has not been saved yet.' )
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
        submit    => [ '#piece_list', {
          action => 'Piece/add',
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
        submit    => [ '#piece_search', {
          action => 'Piece/list',
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

SL::Controller::Piece - Piece CRUD controller

=head1 DESCRIPTION

Implements the URL Actions.
They loads the requesting form and database objects if needed.
Finally prepares and calls the responding form or redirects to the according action.
The output list is realised by a HTML-Template to avoid "bin/mozilla".

=head1 URL ACTIONS

=over 4

=item C<action_add>

Adds a new piece.

=item C<action_delete

Deletes an existing piece.

=item C<action_edit>

Edits an existing piece.

=item C<action_list>

Lists the filtred and sorted piecees.

=item C<action_save>

Saves a new or edited piece and responds the Edit-Form.

=item C<action_save_and_close>

Saves a new or edited piece and closes the frame.

=item C<action_search>

Filters the pieces and their fields to list.

=back

=head1 HELPER FUNCTIONS

=over 4

=item C<_copy>

Copies the fields of a piece from the requesting form to the rose-object.

=item C<_create>

Creates a new piece-rose-object.

=item C<_filter>

Returns the filter of the pieces-query and sets those of the responding form.

=item C<_forward_tags_hidden>

Sets the searche and sort criteria for the callback of the responding form.

=item C<_forward_tags_redirected>

Sets the searche and sort criteria for the callback of the redirected action.

=item C<_load>

Loads the piece-rose-object at the redirected action.

=item C<_pre_render>

Prepares the responding form.

=item C<_redirect_to>

Redirects to the passed action.

=item C<_save>

Saves a new or edited piece.

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
