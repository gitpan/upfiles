#!/usr/bin/perl

# Copyright 2009 Kevin Ryde

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


my $local = \*main::STDOUT;
print $local // 'undef',"\n";
print Data::Dumper->new([\$local],['local'])->Sortkeys(1)->Dump;

my $localfd = ref($local) || ref(\$local) eq "GLOB";
print Data::Dumper->new([\$localfd],['localfd'])->Sortkeys(1)->Dump;

