package SL::Template::Plugin::MultiColumnIterator;

#use strict;
use base 'Template::Plugin';
use Template::Constants;
use Template::Exception;
use Template::Iterator;
use SL::LXDebug;
use Data::Dumper;

our $AUTOLOAD;

sub new {
    $main::lxdebug->enter_sub(); 
    my $class   = shift;
    my $context = shift;
    my $data    = shift || [ ];
    my $dim     = shift || 1;

    $dim        = 1 if $dim < 1;

    use vars qw(@ISA);
    push @ISA, "Template::Iterator";

    if (ref $data eq 'HASH') {
        # map a hash into a list of { key => ???, value => ??? } hashes,
        # one for each key, sorted by keys
        $data = [ map { { key => $_, value => $data->{ $_ } } }
                  sort keys %$data ];
    }
    elsif (UNIVERSAL::can($data, 'as_list')) {
        $data = $data->as_list();
    }
    elsif (ref $data ne 'ARRAY') {
        # coerce any non-list data into an array reference
        $data  = [ $data ] ;
    }

    $main::lxdebug->leave_sub(); 

    bless {
        _DATA  => $data,
        _ERROR => '',
        _DIM   => $dim,
    }, $class;
}


sub get_first {
    $main::lxdebug->enter_sub(); 
    my $self  = shift;
    my $data  = $self->{ _DATA };
    my $dim   = $self->{ _DIM  };

    $self->{ _DATASET } = $self->{ _DATA };
    my $size = int ((scalar @$data - 1) / $dim) + 1;
    my $index = 0;
    
    return (undef, Template::Constants::STATUS_DONE) unless $size;

    # initialise various counters, flags, etc.
    @$self{ qw( SIZE MAX INDEX COUNT FIRST LAST ) } = ( $size, $size - 1, $index, 1, 1, $size > 1 ? 0 : 1, undef );
    @$self{ qw( PREV ) } = ( undef );
    $$self{ qw( NEXT ) } = [ @{ $self->{ _DATASET }  }[ map { $index + 1 + $_ * $size } 0 .. ($dim - 1) ] ];

    $main::lxdebug->leave_sub(); 
    return [ @{ $self->{ _DATASET } }[ map { $index + $_ * $size } 0 .. ($dim - 1) ] ];
}

sub get_next {
    $main::lxdebug->enter_sub(); 
    my $self = shift;
    my ($max, $index) = @$self{ qw( MAX INDEX ) };
    my $data = $self->{ _DATASET };
    my $dim  = $self->{ _DIM  };
    my $size = $self->{ SIZE  };

    # warn about incorrect usage
    unless (defined $index) {
        my ($pack, $file, $line) = caller();
        warn("iterator get_next() called before get_first() at $file line $line\n");
        return (undef, Template::Constants::STATUS_DONE);   ## RETURN ##
    }

    # if there's still some data to go...
    if ($index < $max) {
        # update counters and flags
        $index++;
        @$self{ qw( INDEX COUNT FIRST LAST ) } = ( $index, $index + 1, 0, $index == $max ? 1 : 0 );
        $$self{ qw( PREV ) } = [ @{ $self->{ _DATASET } }[ map { $index - 1 + $_ * $size } 0 .. ($dim - 1) ] ];
        $$self{ qw( NEXT ) } = [ @{ $self->{ _DATASET } }[ map { $index + 1 + $_ * $size } 0 .. ($dim - 1) ] ];
        $main::lxdebug->leave_sub(); 
        return [ @{ $self->{ _DATASET } }[ map { $index + $_ * $size } 0 .. ($dim - 1) ] ];
    }
    else {
        $main::lxdebug->leave_sub(); 
        return (undef, Template::Constants::STATUS_DONE);   ## RETURN ##
    }
}

sub get_all {
    my $self = shift;
    my ($max, $index, $dim, $size) = @$self{ qw( MAX INDEX _DIM SIZE) };
    my (@data, $i);

    # if there's still some data to go...
    if ($index < $max) {
        $index++;
        @data = map do{ !($i = $_) || +[ @{ $self->{ _DATASET } }[ map { $i + $_ * $size } 0 .. ($dim - 1) ] ] }, $index .. $max;
        # update counters and flags
        @$self{ qw( INDEX COUNT FIRST LAST ) } = ( $max, $max + 1, 0, 1 );
        $main::lxdebug->leave_sub();
        return \@data;					    ## RETURN ##
    }
    else {
        $main::lxdebug->leave_sub();
        return (undef, Template::Constants::STATUS_DONE);   ## RETURN ##
    }
}

sub AUTOLOAD {
    my $self = shift;
    my $item = $AUTOLOAD;
    $item =~ s/.*:://;
    return if $item eq 'DESTROY';

    # alias NUMBER to COUNT for backwards compatability
    $item = 'COUNT' if $item =~ /NUMBER/i;

    return $self->{ uc $item };
}

sub dump {
    $main::lxdebug->enter_sub(); 
    my $self = shift;
    $main::lxdebug->leave_sub(); 
    return join('',
         "<pre>",
         "  Data: ", Dumper($self->{ _DATA  }), "\n",
         " Index: ", $self->{ INDEX  }, "\n",
         "Number: ", $self->{ NUMBER }, "\n",
         "   Max: ", $self->{ MAX    }, "\n",
         "  Size: ", $self->{ SIZE   }, "\n",
         " First: ", $self->{ FIRST  }, "\n",
         "  Last: ", $self->{ LAST   }, "\n",
         "\n",
         "</pre>"
     );
}

sub index {
  $main::lxdebug->enter_sub(); 
  my ($self) = @_;
  $main::lxdebug->leave_sub(); 
  return $self->{ INDEX };
}

sub number {
  $main::lxdebug->enter_sub(); 
  my ($self) = @_;
  $main::lxdebug->leave_sub(); 
  return $self->{ NUMBER };
}

sub count {
  $main::lxdebug->enter_sub(); 
  my ($self) = @_;
  $main::lxdebug->leave_sub(); 
  return $self->{ COUNT };
}
sub max {
  $main::lxdebug->enter_sub(); 
  my ($self) = @_;
  $main::lxdebug->leave_sub(); 
  return $self->{ MAX };
}

sub size {
  $main::lxdebug->enter_sub(); 
  my ($self) = @_;
  $main::lxdebug->leave_sub(); 
  return $self->{ SIZE };
}

sub first {
  $main::lxdebug->enter_sub(); 
  my ($self) = @_;
  $main::lxdebug->leave_sub(); 
  return $self->{ FIRST };
}

sub last {
  $main::lxdebug->enter_sub(); 
  my ($self) = @_;
  $main::lxdebug->leave_sub(); 
  return $self->{ LAST};
}

1;
