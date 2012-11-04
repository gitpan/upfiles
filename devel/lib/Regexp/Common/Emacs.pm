# Copyright 2012 Kevin Ryde

# This file is part of Upfiles.
#
# Upfiles is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as published
# by the Free Software Foundation; either version 3, or (at your option) any
# later version.
#
# Upfiles is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Upfiles.  If not, see <http://www.gnu.org/licenses/>.



# directory sep \ for msdos
# backup demanding one non-sep char so /foo/bar/~ is not a backup
# autosave so #f/oo#  is not an autosave

# -numbered
# -unnumbered
# -both

# $RE{emacs}{backup}
# $RE{Emacs}{backup}



package Regexp::Common::Emacs;
use 5.005;
use strict;
use warnings;
use Carp;
# no import(), don't want %RE or builtins, call pattern() by full name
use Regexp::Common ();

use vars '$VERSION';
$VERSION = 7;

# [:digit:] new in perl 5.6, use it if available otherwise 0-9
my $digit = do {
  local $^W = 0;
  eval q{'0' =~ /[[:digit:]]/ ? '[:digit:]' : '0-9'}
    || die "Oops, eval: ",$@;
};

# Ending with "~", per Emacs manual info "(emacs)Backup Names" and function
# backup-file-name-p
# Eg. "foo.c~" or "foo.c.~123~"
Regexp::Common::pattern
  (name   => ['Emacs','backup'],
   create => sub {
     my ($self, $flags) = @_;
     if (exists $flags->{-numonly}) {
       # unnumbered only
       # .* [^[:digit:]/]~
       # .* [^~]\d+~
       # .* [^.]~\d+~
       return '(?k:(?k:.*(?:^|/)[^/]*(?:[^'.$digit.'/]|[^~'.$digit.']\d+|[^.]~\d+))~$)';
     }
     if (exists $flags->{-unonly}) {
       # numbered only
       return '(?k:(?k:.*[^/])\.~(?k:\d+)~$)';
     }
     # numbered or unnumbered
     return '(?k:(?k:.*?[^/])(?:\.~(?k:\d+))?~$)';
   });

# begin and end with "#", per Emacs function auto-save-file-name-p
Regexp::Common::pattern
  (name   => ['Emacs','autosave'],
   create => '(?k:(?:^|/)#[^/]+#$)');

Regexp::Common::pattern
  (name   => ['Emacs','lockfile'],
   create => '(?k:(?:^|/)\.\#[^/]+$)');

Regexp::Common::pattern
  (name   => ['Emacs','skipfile'],
   create => '(?k:(?:(?:^|/)\.?\#[^/]+|~)$)');

1;
__END__

=head1 NAME

Regexp::Common::Emacs -- regexps for some Emacs filenames

=for test_synopsis my ($str)

=head1 SYNOPSIS

 use Regexp::Common 'Emacs', 'no_defaults';
 if ($str =~ /$RE{Emacs}{backup}/) {
    # ...
 }
 my $regexp1 = $RE{Emacs}{lockfile};

 # Subroutine style
 use Regexp::Common 'RE_Emacs_autosave';
 my $regexp2 = RE_Emacs_autosave();

=head1 DESCRIPTION

See L<Regexp::Common> for the basics of C<Regexp::Common> patterns ...

=over

=item C<$RE{Emacs}{backup}>

Match an Emacs backup filename.  This is

    foo.c~                     unnumbered
    foo.c.~123~                numbered
    /some/dir/foo.c~           and with directory
    /some/dir/foo.c.~123~

With the C<-keep> option the captures are

    $1       whole string
    $2       originating filename, such as "/some/dir/foo.c"
    $3       backup number such as "123", or undef if unnumbered

Options can restrict to numbered or unnumbered backups only

=over

=item C<-numonly>

Match only numbered backup files F<foo.c..~123~>, not unnumbered ones.

=item C<-unonly>

Match only unnumbered backup files F<foo.c~>, not numbered ones.

A suffix F<foo.c.~123~> etc is presumed to be a numbered backup.  Of course
it's possible this is not a numbered backup but is instead from a file which
happened to be called F<foo.c.~123> and gained an F<~> as an unnumbered
backup.  Hopefully files named that way would be unusual.

=back

Emacs makes a backup of file contents before saving, once in each editing
session.  The default is a single unnumbered backup F<foo.c~>, or if the
C<version-control> variable is set then rolling numbered backups
F<foo.c.~1~>, F<foo.c.~2~>, F<foo.c.~3~> etc.  See "Backup Files" in the
Emacs manual.

=item C<$RE{Emacs}{lockfile}>

Match an Emacs lockfile filename.  This is

    .#foo.c
    /some/directory/.#foo.c

With the C<-keep> option the only capture is

    $1       whole string

Emacs creates a lockfile to prevent two users or two running copies of Emacs
from editing a file simultaneously.  On a Unix-like system a lockfile is
normally a symlink to a non-existent file so ignoring dangling symlinks will
also ignore Emacs lockfiles.  See "File Locks" in the Emacs manual.

=item C<$RE{Emacs}{autosave}>

Match an Emacs autosave filename.  This is

    #foo.c#
    /some/directory/#foo.c#

With the C<-keep> option the only capture is

    $1       whole string

Emacs creates an autosave file with the contents of a file buffer being
edited.  It's used to recover those edits in the event of a system crash
(C<M-x recover-file> or C<M-x recover-this-file>).  See "Auto-Saving" in the
Emacs manual.

=item C<$RE{Emacs}{skipfile}>

Match an Emacs backup, lockfile or autosave filename.  This is any of the
above forms

    foo.c~             backup
    foo.c.~123~        backup
    .#foo.c            lockfile
    #foo.c#            autosave
                       and with a directory part too

With the C<-keep> option the only capture is

    $1       whole string

=back

=head1 IMPORTS

This module should be loaded through the C<Regexp::Common> mechanism, see
L<Regexp::Common/Loading specific sets of patterns.>.  Remember that loading
a non-core pattern like Emacs also loads all the builtin patterns.

    # Emacs plus all builtins
    use Regexp::Common 'Emacs';

If you want only C<$RE{Emacs}> then add C<no_defaults> (or a specific set of
builtins desired).

    # Emacs alone
    use Regexp::Common 'Emacs', 'no_defaults';

=head1 SEE ALSO

L<Regexp::Common>

=head1 HOME PAGE

http://user42.tuxfamily.org/upfiles/index.html

=head1 LICENSE

Copyright 2012 Kevin Ryde

Upfiles is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by the
Free Software Foundation; either version 3, or (at your option) any later
version.

Upfiles is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
more details.

You should have received a copy of the GNU General Public License along with
Upfiles.  If not, see <http://www.gnu.org/licenses/>.

=cut
