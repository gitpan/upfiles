#!/usr/bin/perl -w

# Copyright 2009, 2010, 2011, 2012, 2014 Kevin Ryde

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
use ExtUtils::MakeMaker;

WriteMakefile
  (NAME         => 'upfiles',
   ABSTRACT     => 'Upload files to a remote FTP server.',
   VERSION_FROM => 'lib/App/Upfiles.pm',
   AUTHOR       => 'Kevin Ryde <user42_kevin@yahoo.com.au>',
   LICENSE      => 'gpl_3',
   SIGN         => 1,
   EXE_FILES    => [ 'upfiles' ],
   PREREQ_PM    => {
                    'DBI' => 0,
                    'DBD::SQLite' => 0,
                    'File::HomeDir' => 0,
                    'Locale::TextDomain' => 0,
                    'Math::Round' => 0,
                    'Regexp::Common' => 0,
                    'Regexp::Common::Emacs' => 0,
                    'URI' => 0,
                   },
   MIN_PERL_VERSION => '5.010',

   META_MERGE =>
   { resources =>
     { homepage => 'http://user42.tuxfamily.org/upfiles/index.html',
       license  => 'http://www.gnu.org/licenses/gpl.html',
     },
     no_index => { directory=>['devel','xt'],
                 },
   },
  );
