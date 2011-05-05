# Copyright (c) 2010 Elizabeth Grace Frank-Backman.
# All rights reserved.
# Liscenced under the "Artistic Liscence"
# (see http://dev.perl.org/licenses/artistic.html)

use 5.8.8;
use strict;
use warnings;
use overload;

package Exception::Lite;
our @ISA = qw(Exporter);
our @EXPORT_OK=qw(declareExceptionClass isException isChainable
                  onDie onWarn);
our %EXPORT_TAGS
  =( common => [qw(declareExceptionClass isException isChainable)]
     , all => [@EXPORT_OK]
   );
my $CLASS='Exception::Lite';

#------------------------------------------------------------------

our $STRINGIFY=3;
our $FILTER=1;
our $UNDEF='<undef>';
our $TAB=3;
our $LINE_LENGTH=120;

# provide command line control over amount and layout of debugging
# information, e.g. perl -mException::Lite=STRINGIFY=4

sub import {
  Exception::Lite->export_to_level(1, grep {
    if (/^(\w+)=(.*)$/) {
      my $k = $1;
      my $v = $2;
      if ($k eq 'STRINGIFY')        { $STRINGIFY=$v;
      } elsif ($k eq 'FILTER')      { $FILTER=$v;
      } elsif ($k eq 'LINE_LENGTH') { $LINE_LENGTH=$v;
      } elsif ($k eq 'TAB')         { $TAB=$v;
      }
      0;
    } else {
      1;
    }
  } @_);
}

#------------------------------------------------------------------
# Note to source code divers: DO NOT USE THIS. This is intended for
# internal use but must be declared with "our" because we need to
# localize it.  This is an implementation detail and cannot be relied
# on for future releases.

our $STACK_OFFSET=0;

#------------------------------------------------------------------

use Scalar::Util ();
use constant EVAL => '(eval)';

#==================================================================
# EXPORTABLE FUNCTIONS
#==================================================================

sub declareExceptionClass {
  my ($sClass, $sSuperClass, $xFormatRule, $bCustomizeSubclass) = @_;
  my $sPath = $sClass; $sPath =~ s/::/\//g; $sPath .= '.pm';
  if ($INC{$sPath}) {
    # we want to start with the caller's frame, not ours
    local $STACK_OFFSET = $STACK_OFFSET + 1;
    die 'Exception::Lite::Any'->new("declareExceptionClass failed: "
                                    . "$sClass is already defined!");
    return undef;
  }

  my $sRef=ref($sSuperClass);
  if ($sRef) {
    $bCustomizeSubclass = $xFormatRule;
    $xFormatRule = $sSuperClass;
    $sSuperClass=undef;
  } else {
    $sRef = ref($xFormatRule);
    if (!$sRef && defined($xFormatRule)) {
      $bCustomizeSubclass = $xFormatRule;
      $xFormatRule = undef;
    }
  }

  # set up things dependent on whether or not the class has a
  # format string or expects a message for each instance

  my ($sLeadingParams, $sAddOrOmit, $sRethrowMsg, $sMakeMsg);
  my $sReplaceMsg='';

  if ($sRef) {
    $sLeadingParams='my $e; $e=shift if ref($_[0]);';
    $sAddOrOmit='added an unnecessary message or format';
    $sRethrowMsg='';

    #generate format rule
    $xFormatRule=$xFormatRule->($sClass) if ($sRef eq 'CODE');

    my $sFormat= 'q{' . $xFormatRule->[0] . '}';
    if (scalar($xFormatRule) == 1) {
      $sMakeMsg='my $msg='.$sFormat;
    } else {
      my $sSprintf = 'Exception::Lite::_sprintf(' . $sFormat
        . ', map {defined($_)?$_:\''. $UNDEF .'\'} @$h{qw('
        . join(' ', @$xFormatRule[1..$#$xFormatRule]) . ')});';
      $sMakeMsg='my $msg='.$sSprintf;
      $sReplaceMsg='$_[0]->[0]='.$sSprintf;
    }

  } else {
    $sLeadingParams = 'my $e=shift; my $msg;'.
      'if(ref($e)) { $msg=shift; $msg=$e->[0] if !defined($msg);}'.
      'else { $msg=$e;$e=undef; }';
    $sAddOrOmit='omitted a required message';
    $sRethrowMsg='my $msg=shift; $_[0]->[0]=$msg if defined($msg);';
    $sMakeMsg='';
  }

  # put this in an eval so that it doesn't cause parse errors at
  # compile time in no-threads versions of Perl

  my $sTid = eval q{defined(&threads::tid)?'threads->tid':'undef'};

  my $sDeclare = "package $sClass;".
    'sub new { my $cl=shift;'.  $sLeadingParams .
      'my $st=Exception::Lite::_cacheStackTrace($e);'.
      'my $h= Exception::Lite::_shiftProperties($cl' .
         ',$st,"'.$sAddOrOmit.'",@_);' . $sMakeMsg .
      'my $self=bless([$msg,$h,$st,$$,'.$sTid.',$e,[]],$cl);';

  # the remainder depends on the type of subclassing

  if ($bCustomizeSubclass) {
    $sDeclare .= '$self->[7]={}; $self->_new(); return $self; }'
      . 'sub _p_getSubclassData { $_[0]->[7]; }';
  } else {
    $sDeclare .= 'return $self;}'.
    'sub replaceProperties {'.
       'my $h={%{$_[0]->[1]},%{$_[1]}}; $_[0]->[1]=$h;'.$sReplaceMsg.
    '}'.
    'sub rethrow {' .
      'my $self=shift;' . $sRethrowMsg .
      'Exception::Lite::_rethrow($self,"'.$sAddOrOmit.'",@_)' .
    '}';

    unless (isExceptionClass($sSuperClass)) {
      $sDeclare .=
        'sub _getInterface { \'Exception::Lite\' }' .
        'sub getMessage { $_[0]->[0] };' .
        'sub getProperty { $_[0]->[1]->{$_[1]} }' .
        'sub isProperty { exists($_[0]->[1]->{$_[1]})?1:0 }' .
        'sub getStackTrace { $_[0]->[2] }' .
        'sub getFrameCount { scalar(@{$_[0]->[2]}); }' .
        'sub getFile { $_[0]->[2]->[ $_[1]?$_[1]:0 ]->[0] };' .
        'sub getLine { $_[0]->[2]->[ $_[1]?$_[1]:0 ]->[1] };' .
        'sub getSubroutine { $_[0]->[2]->[ $_[1]?$_[1]:0 ]->[2] };' .
        'sub getArgs { $_[0]->[2]->[ $_[1]?$_[1]:0 ]->[3] };' .
        'sub getPackage {$_[0]->[2]->[-1]->[2] =~ /(\w+)>$/;$1}'.
        'sub getPid { $_[0]->[3] }' .
        'sub getTid { $_[0]->[4] }' .
        'sub getChained { $_[0]->[5] }' .
        'sub getPropagation { $_[0]->[6]; }' .
        'use overload '.
           'q{""} => \&Exception::Lite::_dumpMessage ' .
           ', q{0+} => \&Exception::Lite::_refaddr, fallback=>1;' .
        'sub PROPAGATE { push @{$_[0]->[6]},[$_[1],$_[2]]; $_[0]}';
    }
  }
  $sDeclare .= 'return 1;';

  local $SIG{__WARN__} = sub {
    my ($p,$f,$l) = caller(2);
    my $s=$_[0]; $s =~ s/at \(eval \d+\)\s+line\s+\d+\.//m;
    print STDERR "$s in declareExceptionClass($sClass,...) "
      ."in file $f, line $l\n";
  };

  eval $sDeclare or do {
    my ($p,$f,$l) = caller(1);
    print STDERR "Can't create class $sClass at file $f, line $l\n";
    if ($sClass =~ /\w:\w/) {
      print STDERR "Bad class name: "
        ."At least one ':' is not doubled\n";
    } elsif ($sClass !~ /^\w+(?:::\w+)*$/) {
      print STDERR "Bad class name: $sClass\n";
    } else {
      $sDeclare=~s/(sub |use )/\n$1/g; print STDERR "$sDeclare\n";
    }
  };

  # this needs to be separate from the eval, otherwise it never
  # ends up in @INC or @ISA, at least in Perl 5.8.8
  $INC{$sPath} = __FILE__;
  eval "\@${sClass}::ISA=qw($sSuperClass);" if $sSuperClass;

  return $sClass;
}

#------------------------------------------------------------------

sub isChainable { return ref($_[0])?1:0; }

#------------------------------------------------------------------

sub isException {
  my ($e, $sClass) = @_;
  my $sRef=ref($e);
  return !defined($sClass)
    ? ($sRef ? isExceptionClass($sRef) : 0)
    : $sClass eq ''
       ? ($sRef eq '' ? 1 : 0)
       : ($sRef eq '')
            ? 0
            : $sRef->isa($sClass)
               ?1:0;
}

#------------------------------------------------------------------

sub isExceptionClass {
  return defined($_[0]) && $_[0]->can('_getInterface')
    && ($_[0]->_getInterface() eq __PACKAGE__) ? 1 : 0;
}

#------------------------------------------------------------------

sub onDie {
  my $iStringify = $_[0];
  $SIG{__DIE__} = sub {
    $Exception::Lite::STRINGIFY=$iStringify;
    warn 'Exception::Lite::Any'->new('Unexpected death:'.$_[0])
      unless $^S || isException($_[0]);
  };
}

#------------------------------------------------------------------

sub onWarn {
  my $iStringify = $_[0];
  $SIG{__WARN__} = sub {
    $Exception::Lite::STRINGIFY=$iStringify;
    print STDERR 'Exception::Lite::Any'->new("Warning: $_[0]");
  };
}

#==================================================================
# PRIVATE SUBROUTINES
#==================================================================

#------------------------------------------------------------------

sub _cacheCall {
  my $iFrame = $_[0];

  my @aCaller;
  my $aArgs;

  # caller populates @DB::args if called within DB package
  eval {
    # this 2 line wierdness is needed to prevent Module::Build from finding
    # this and adding it to the provides list.
    package
      DB;

    #get rid of eval and call to _cacheCall
    @aCaller = caller($iFrame+2);

    # mark leading undefined elements as maybe shifted away
    my $iDefined;
    if ($#aCaller < 0) {
      @DB::args=@ARGV;
    }
    $aArgs = [  map {
      defined($_)
        ? do {$iDefined=1;
              "'$_'" . (overload::Method($_,'""')
                        ? ' ('.overload::StrVal($_).')':'')}
          : 'undef' . (defined($iDefined)
                       ? '':'  (maybe shifted away?)')
        } @DB::args];
  };

  return $#aCaller < 0 ? \$aArgs : [ @aCaller[0..3], $aArgs ];
}

#------------------------------------------------------------------

sub _cacheStackTrace {
  my $e=$_[0]; my $st=[];

  # set up initial frame
  my $iFrame= $STACK_OFFSET + 1; # call to new
  my $aCall = _cacheCall($iFrame++);
  my ($sPackage, $iFile, $iLine, $sSub, $sArgs) = @$aCall;
  my $iLineFrame=$iFrame;

  $aCall =  _cacheCall($iFrame++);  #context of call to new
  while (ref($aCall) ne 'REF') {
    $sSub  = $aCall->[3];  # subroutine containing file,line
    $sArgs = $aCall->[4];  # args used to call $sSub

    #print STDERR "debug-2: package=$sPackage file=$iFile line=$iLine"
    #  ." sub=$sSub, args=@$sArgs\n";

    # in evals we want the line number within the eval, but the
    # name of the sub in which the eval was located. To get this
    # we wait to push on the stack until we get an actual sub name
    # and we avoid overwriting the location information, hence 'ne'

    if (!$FILTER || ($sSub ne EVAL)) {
      my $aFrame=[ $iFile, $iLine, $sSub, $sArgs ];
      ($sPackage, $iFile, $iLine) = @$aCall;
      $iLineFrame=$iFrame;

      my $sRef=ref($FILTER);
      if ($sRef eq 'CODE') {
        my $x = $FILTER->(@$aFrame, $iFrame, $iLineFrame);
        if (ref($x) eq 'ARRAY') {
          $aFrame=$x;
        } elsif (!$x) {
          $aFrame=undef;
        }
      } elsif (($sRef eq 'ARRAY') && ! _isIgnored($sSub, $FILTER)) {
        $aFrame=undef;
      } elsif (($sRef eq 'Regexp') && !_isIgnored($sSub, [$FILTER])) {
        $aFrame=undef;
      }
      push(@$st, $aFrame) if $aFrame;
    }

    $aCall = _cacheCall($iFrame++);
  }

  push @$st, [ $iFile, $iLine, "<package: $sPackage>", $$aCall ];
  if ($e) { my $n=$#{$e->[2]}-$#$st;$e->[2]=[@{$e->[2]}[0..$n]]};
  return $st;
}

#-----------------------------

sub _isIgnored {
  my ($sSub, $aIgnore) = @_;
  foreach my $re (@$aIgnore) { return 1 if $sSub =~ $re; }
  return 0;
}

#------------------------------------------------------------------

sub _dumpMessage {
  my ($e, $iDepth) = @_;

  my $sMsg = $e->getMessage();
  return $sMsg unless $STRINGIFY;
  if (ref($STRINGIFY) eq 'CODE') {
    return $STRINGIFY->($sMsg);
  }

  $iDepth = 0 unless defined($iDepth);
  my $sIndent = ' ' x ($TAB*$iDepth);
  $sMsg = "\n${sIndent}Exception! $sMsg";
  return $sMsg if $STRINGIFY == 0;

  my ($sThrow, $sReach);
  my $sTab = ' ' x $TAB;

  $sIndent.= $sTab;
  if ($STRINGIFY > 2) {
    my $aPropagation = $e->getPropagation();
    for (my $i=$#$aPropagation; $i >= 0; $i--) {
      my ($f,$l) = @{$aPropagation->[$i]};
      $sMsg .= "\n${sIndent}rethrown at file $f, line $l";
    }
    $sMsg .= "\n";
    $sThrow='thrown  ';
    $sReach='reached ';
  } else {
    $sThrow='';
    $sReach='';
  }

  my $st=$e->getStackTrace();
  my $iTop = scalar @$st;

  for (my $iFrame=0; $iFrame<$iTop; $iFrame++) {
    my ($f,$l,$s,$aArgs) = @{$st->[$iFrame]};

    if ($iFrame) {
      #2nd and following stack frame
      my $sVia="${sIndent}${sReach}via file $f, line $l";
      my $sLine="$sVia in $s";
      $sMsg .= (length($sLine)>$LINE_LENGTH
                ? "\n$sVia\n$sIndent${sTab}in $s" : "\n$sLine");
    } else {
      # first stack frame
      my $tid=$e->getTid();
      my $sAt="${sIndent}${sThrow}at  file $f, line $l";
      my $sLine="$sAt in $s";
      $sMsg .= (length($sLine)>$LINE_LENGTH
                ? "\n$sAt\n$sIndent${sTab}in $s" : "\n$sLine")
        . ", pid=" . $e->getPid() . (defined($tid)?", tid=$tid":'');

      return "$sMsg\n" if $STRINGIFY == 1;
    }

    if ($STRINGIFY > 3) {
      my $bTop = ($iFrame+1) == $iTop;
      my $sVar= ($bTop && !$iDepth) ? '@ARGV' : '@_';
      my $bMaybeEatenByGetOpt = $bTop && !scalar(@$aArgs)
        && exists($INC{'Getopt/Long.pm'});

      my $sVarIndent = "\n${sIndent}" . (' ' x $TAB);
      my $sArgPrefix = "${sVarIndent}".(' ' x length($sVar)).' ';
      if ($bMaybeEatenByGetOpt) {
        $sMsg .= $sArgPrefix . $sVar
          . '()    # maybe eaten by Getopt::Long?';
      } else {
        my $sArgs = join($sArgPrefix.',', @$aArgs);
        $sMsg .= "${sVarIndent}$sVar=($sArgs";
        $sMsg .= $sArgs ? "$sArgPrefix)" : ')';
      }
    }
  }
  $sMsg.="\n";
  return $sMsg if $STRINGIFY == 2;

  my $eChained = $e->getChained();
  if (defined($eChained)) {
    my $sTrigger = isException($eChained)
      ? _dumpMessage($eChained, $iDepth+1)
      : "\n${sIndent}$eChained\n";
    $sMsg .= "\n${sIndent}Triggered by...$sTrigger";
  }
  return $sMsg;
}

#------------------------------------------------------------------

# refaddr has a prototype($) so we can't use it directly as an
# overload operator: it complains about being passed 3 parameters
# instead of 1.
sub _refaddr { Scalar::Util::refaddr($_[0]) };

#------------------------------------------------------------------

sub _rethrow {
  my $self = shift; my $sAddOrOmit = shift;
  my ($p,$f,$l)=caller(1);
  $self->PROPAGATE($f,$l);

  if (@_%2) {
    warn sprintf('bad parameter list to %s->rethrow(...)'
      .'at file %d, line %d: odd number of elements in property-value '
      .'list, property value has no property name and will be '
      ."discarded (common causes: you have %s string)\n"
      ,$f, $l, $sAddOrOmit);
    shift @_;
  }
  $self->replaceProperties({@_}) if (@_);
  return $self;
}

#------------------------------------------------------------------
# Traps warnings and reworks them so that they tell the user how
# to fix the problem rather than obscurely complain about an
# invisible sprintf with uninitialized values that seem to come from
# no where (and make Exception::Lite look like it is broken)

sub _sprintf {
  my $sMsg;
  my $sWarn;

  {
    local $SIG{__WARN__} = sub { $sWarn=$_[0] if !defined($sWarn) };

    # sprintf has prototype ($@)
    my $sFormat = shift;
    $sMsg = sprintf($sFormat, @_);
  }

  if (defined($sWarn)) {
    my $sReason='';
    my ($f, $l, $s) = (caller(1))[1,2,3];
    $s =~ s/::(\w+)\z/->$1/;
    $sWarn =~ s/sprintf/$s/;
    $sWarn =~ s/\s+at\s+[\w\/\.]+\s+line\s+\d+\.\s+\z//;
    if ($sWarn
        =~ m{^Use of uninitialized value in|^Missing argument}) {
      my $p=$s; $p =~ s/->\w+\z//;
      $sReason ="\n     Most likely cause: "
        . "Either you are missing property-value pairs needed to"
        . "build the message or your exception class's format"
        . "definition mistakenly has too many placeholders "
        . "(e.g. %s,%d,etc)\n";
    }
    warn "$sWarn called at file $f, line $l$sReason\n";
  }
  return $sMsg;
}

#------------------------------------------------------------------

sub _shiftProperties {
  my $cl= shift;  my $st=shift;  my $sAddOrOmit = shift;
  if (@_%2) {
    $"='|';
    warn sprintf('bad parameter list to %s->new(...) at '
      .'file %s, line %d: odd number of elements in property-value '
      .'list, property value has no property name and will be '
      .'discarded (common causes: you have %s string -or- you are '
      ."using a string as a chained exception)\n"
      ,$cl,$st->[0]->[0],$st->[0]->[1], $sAddOrOmit);
    shift @_;
  }
  return {@_};
}

#==================================================================
# MODULE INITIALIZATION
#==================================================================

declareExceptionClass(__PACKAGE__ .'::Any');
1;
