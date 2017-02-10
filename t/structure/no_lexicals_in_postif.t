use strict;
use threads;
use lib 't';
use Support::Files;
use Sys::CPU;
use Test::More;
use Thread::Pool::Simple;

if (eval { require PPI; 1 }) {
  plan tests => scalar(@Support::Files::testitems);
} else {
  plan skip_all => "PPI not installed";
}

my $fh;
{
    local $^W = 0;  # Don't complain about non-existent filehandles
    if (-e \*Test::More::TESTOUT) {
        $fh = \*Test::More::TESTOUT;
    } elsif (-e \*Test::Builder::TESTOUT) {
        $fh = \*Test::Builder::TESTOUT;
    } else {
        $fh = \*STDOUT;
    }
}

my @testitems = @Support::Files::testitems;

sub test_file {
  my ($file) = @_;
  my $clean = 1;
  my $source;
  {
    # due to a bug in PPI it cannot determine the encoding of a source file by
    # use utf8; normaly this would be no problem but some people instist on
    # putting strange stuff into the source. as a workaround read in the source
    # with :utf8 layer and pass it to PPI by reference
    # there are still some latin chars, but it's not the purpose of this test
    # to find them, so warnings about it will be ignored
    local $^W = 0; # don't care about invalid chars in comments
    local $/ = undef;
    open my $fh, '<:utf8', $file or die $!;
    $source = <$fh>;
  }

  my $doc = PPI::Document->new(\$source) or do {
    print $fh "?: PPI error for file $file: " . PPI::Document::errstr() . "\n";
    ok 0, $file;
    next;
  };
  my $stmts = $doc->find('Statement::Variable');

  for my $var (@{ $stmts || [] }) {
    # local can have valid uses like this, and our is extremely uncommon
    next unless $var->type eq 'my';

    # no if? alright
    next unless $var->find(sub { $_[1]->content eq 'if' });

    # token "if" is not in the top level struvture - no problem
    # most likely an anonymous sub or a complicated map/grep/reduce
    next unless grep { $_->content eq 'if'  } $var->schildren;

    $clean = 0;
    print $fh "?: $var \n";
  }

  ok $clean, $file;
}

my $pool = Thread::Pool::Simple->new(
  min    => 2,
  max    => Sys::CPU::cpu_count() + 1,
  do     => [ \&test_file ],
  passid => 0,
);

$pool->add($_) for @testitems;

$pool->join;
