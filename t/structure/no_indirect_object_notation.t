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
    print "?: PPI error for file $file: " . PPI::Document::errstr() . "\n";
    ok 0, $file;
    next;
  };
  my $stmts = $doc->find(sub { $_[1]->isa('PPI::Token::Word') && $_[1]->content eq 'new' });

  for my $stmt (@{ $stmts || [] }) {
    my @schildren = $stmt->parent->schildren;
    for (0..$#schildren-1) {
      my $this = $schildren[$_];
      my $next = $schildren[$_+1];

      next unless $this->isa('PPI::Token::Word');
      next unless $this->content eq 'new';
      next unless $next->isa('PPI::Token::Word');

      # suspicious. 2 barewords in a row, with the first being 'new'
      # but maybe its somethiing like: Obj->new param1 => ...
      # check if the one before exists and is a ->
      next if $_ == 0 || ($schildren[$_-1]->isa('PPI::Token::Operator') && $schildren[$_-1]->content eq '->');

      $clean = 0;
      print "?: @{[ $this->content, $next->content ]} \n";
    }
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
