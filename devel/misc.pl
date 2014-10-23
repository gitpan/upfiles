#!/usr/bin/perl -w

# Copyright 2009, 2010, 2012 Kevin Ryde

# This file is part of Upfiles.
#
# Upfiles is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 3, or (at your option) any later
# version.
#
# Upfiles is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with Upfiles.  If not, see <http://www.gnu.org/licenses/>.

use 5.010;
use strict;
use warnings;
use Data::Dumper;

# uncomment this to run the ### lines
#use Smart::Comments;

{
  require Tie::StdHandle;
  tie *FH, 'Tie::StdHandle', '/etc/TextConfig.orig';
  print "size ",-s FH // '[undef]',"\n";
  print "tell ",tell(FH) // '[undef]',"\n";
  print "tied ",tied(*FH) // '[undef]',"\n";
  exit 0;
}

{
  require Tie::StdHandle;
  require Symbol;
  my $fh = Symbol::gensym();
  tie *$fh, 'Tie::StdHandle';
  open $fh, '<', '/etc/TextConfig.orig' or die "$!";
  print "size ",-s $fh // '[undef]',"\n";
  print "tell ",tell($fh) // '[undef]',"\n";
  print "tied ",tied(*$fh) // '[undef]',"\n";
  exit 0;
}

{
  {
    package App::Upfiles::Tie::Handle::Throttle;
    use strict;
    use warnings;
    use Time::HiRes;
    use List::Util 'min';
    use Hash::Util::FieldHash 'register','id';
    use Tie::StdHandle;

    our $VERSION = 4;
    our @ISA = ('Tie::StdHandle');

    Hash::Util::FieldHash::fieldhashes (\(my %blocksize),
                                        \(my %period),
                                        \(my %upto),
                                        \(my %last_time));

    sub TIEHANDLE {
      my ($class, %options) = shift;

      my $self    = $class->SUPER::TIEHANDLE;
      my $id = id $self;
      register($self, \%blocksize, \%period, \%upto, \%last_time);
      $blocksize{$id} = $options{'blocksize'} || 4096;
      $period{$id}    = $options{'period'} || 4096;
      $upto{$id}      = 0;
      $last_time{$id} = Time::HiRes::time();
      return $self;


      # \do { local *HANDLE};
      # bless $self,$class;
      # 
      # return bless { blocksize => 4096,
      #                period    => 1,
      #                upto      => 0,
      #                last_time =>
      #                @_ }, $class;
    }
    # sub OPEN {
    #   my ($self) = @_;
    #   if ($self->{'fh'}) {
    #     $self->CLOSE;
    #   }
    #   return (@_ == 2
    #           ? open($self->{'fh'}, $_[1])
    #           : open($self->{'fh'}, $_[1], $_[2]));
    # }
    # sub CLOSE {
    #   my ($self) = @_;
    #   return close ($self->{'fh'});
    # }
    # sub EOF     {
    #   my ($self) = @_;
    #   return eof($self->{'fh'});
    # }
    # sub TELL    {
    #   my ($self) = @_;
    #   return tell($self->{'fh'});
    # }
    # sub FILENO  {
    #   my ($self) = @_;
    #   return fileno($self->{'fh'});
    # }
    # sub SEEK    {
    #   my ($self) = @_;
    #   return seek($self->{'fh'},$_[1],$_[2]);
    # }
    # sub BINMODE {
    #   my ($self) = @_;
    #   return binmode($self->{'fh'});
    # }

    sub READ {
      my $self = $_[0];
      my $len = $_[2];
      $self->choke;
      my $remaining = $self->{'blocksize'} - $self->{'upto'};
      $len = min ($len, $remaining);
      my $ret = read($self,$_[1],$len);
      if (defined $ret) {
        $self->{'upto'} += $ret;
      }
      return $ret;
    }

    sub READLINE {
      my ($self) = @_;
      $self->choke;
      my $fh = $self; # ->{'fh'};
      my $ret = <$fh>;
      if (defined $ret) {
        $self->{'upto'} += length($ret);
      }
      return $ret;
    }
    sub GETC {
      my ($self) = @_;
      $self->choke;
      my $ret = getc($self);
      if (defined $ret) {
        $self->{'upto'}++;
      }
      return $ret;
    }

    sub choke {
      my ($self) = @_;
      my $remaining = $self->{'blocksize'} - $self->{'upto'};
      if ($remaining <= 0) {
        my $now = Time::HiRes::time();
        my $sleep = $self->{'last_time'} + $self->{'period'} - $now;
        ### $sleep
        if ($sleep > 0 && $sleep < 5) {
          Time::HiRes::sleep ($sleep);
        }
        $self->{'upto'} = 0;
        $self->{'last_time'} = $now;
      }
    }
    sub WRITE {
      die;
    }
  }

  print "VERSION ",App::Upfiles::Tie::Handle::Throttle->VERSION,"\n";
  print "isa ",App::Upfiles::Tie::Handle::Throttle->isa('Tie::Handle'),"\n";

  require Symbol;
  my $fh = Symbol::gensym();
  tie *$fh, 'App::Upfiles::Tie::Handle::Throttle',
    blocksize => 64,
    period => 2;
  $| = 1;
  open $fh, '<', '/etc/TextConfig.orig' or die "$!";
  print "size ",-s $fh // '[undef]',"\n";

  while (read ($fh, my $buf, 3)) {
    Time::HiRes::sleep (3/(64/3));
    print $buf;
  }
  # while (defined (my $c = getc $fh)) {
  #   print $c;
  # }
  # while (defined (my $line = <$fh>)) {
  #   print $line;
  # }
  exit 0;
}

{
  my $local = \*main::STDOUT;
  print $local // 'undef',"\n";
  print Data::Dumper->new([\$local],['local'])->Sortkeys(1)->Dump;

  my $localfd = ref($local) || ref(\$local) eq "GLOB";
  print Data::Dumper->new([\$localfd],['localfd'])->Sortkeys(1)->Dump;
}

