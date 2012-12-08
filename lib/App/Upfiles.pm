# Copyright 2009, 2010, 2011, 2012 Kevin Ryde

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


# Net::FTP
# RFC 959 - ftp
# RFC 1123 - ftp minimum requirements
# http://cr.yp.to/ftp.html  DJB's notes
#

package App::Upfiles;
use 5.010;
use strict;
use warnings;
use Carp;
use File::Spec;
use File::stat;
use List::Util 'max';
use POSIX ();
use Locale::TextDomain ('App-Upfiles');
use Regexp::Common 'no_defaults','Emacs';

use FindBin;
my $progname = $FindBin::Script;

our $VERSION = 8;

# uncomment this to run the ### lines
#use Smart::Comments;


use constant { DATABASE_FILENAME       => '.upfiles.sqdb',
               DATABASE_SCHEMA_VERSION => 1,

               CONFIG_FILENAME => '.upfiles.conf',

               # emacs backups, autosaves, lockfiles
               EXCLUDE_BASENAME_REGEXPS_DEFAULT => [ $RE{Emacs}{skipfile} ],

               EXCLUDE_REGEXPS_DEFAULT => [],
             };

#------------------------------------------------------------------------------
sub new {
  my $class = shift;
  return bless { total_size_kbytes  => 0,
                 total_count        => 0,
                 change_count       => 0,
                 change_size        => 0,
                 verbose            => 1,

                 exclude_regexps_default
                 => $class->EXCLUDE_REGEXPS_DEFAULT,

                 exclude_basename_regexps_default
                 => $class->EXCLUDE_BASENAME_REGEXPS_DEFAULT,

                 @_ }, $class;
}


#------------------------------------------------------------------------------
sub command_line {
  my ($self) = @_;

  my $action = '';
  my $set_action = sub {
    my ($new_action) = @_;
    if ($action) {
      croak __x('Cannot have both action {action1} and {action2}',
                action1 => "--$action",
                action2 => "--$new_action");
    }
    $action = "$new_action"; # stringize against callback object :-(
  };

  require Getopt::Long;
  Getopt::Long::Configure ('no_ignore_case',
                           'bundling');
  if (! Getopt::Long::GetOptions ('help|?'    => $set_action,
                                  'verbose:+' => \$self->{'verbose'},
                                  'V+'        => \$self->{'verbose'},
                                  'version'   => $set_action,
                                  'n|dry-run' => \$self->{'dry_run'},
                                  'nosend'    => \$self->{'nosend'},
                                  'f'         => $set_action,
                                 )) {
    return 1;
  }

  if ($self->{'verbose'} >= 2) {
    print "Verbosity level $self->{'verbose'}\n";
  }
  $action = 'action_' . ($action || 'upfiles');
  return $self->$action;
}

sub action_version {
  my ($self) = @_;
  print __x("upfiles version {version}\n",
            version => $self->VERSION);
  if ($self->{'verbose'} >= 2) {
    require DBI;
    require DBD::SQLite;
    print __x("  Perl        version {version}\n", version => $]);
    print __x("  DBI         version {version}\n", version => $DBI::VERSION);
    print __x("  DBD::SQLite version {version}\n", version => $DBD::SQLite::VERSION);
  }
  return 0;
}

sub action_help {
  my ($self) = @_;
  print __x("Usage: $progname [--options]\n");
  print __x("  --help         print this message\n");
  print __x("  --version      print version number (and module versions if --verbose=2)\n");
  print __x("  -n, --dry-run  don't do anything, just print what would be done\n");
  print __x("  --verbose, --verbose=N
                 print diagnostic info, with --verbose=2 print even more info\n");
  return 0;
}

sub action_upfiles {
  my ($self, @files) = @_;
  ### action_upfiles() ...
  ### @ARGV

  if (@ARGV) {
    # files given on command line
    @files = @ARGV;
    @files = map {File::Spec->rel2abs($_)} @files;
    ### @files
    @files = map {$_, parent_directories($_)} @files;
    ### @files
    my %hash;
    @hash{@files} = (); # hash slice
    ### %hash
    local $self->{'action_files_hash'} = \%hash;
    $self->do_config_file;

  } else {
    # all files
    $self->do_config_file;

    print __x("changed {change_count} files {change_size_kbytes}k, total {total_count} files {total_size_kbytes}k (in 1024 byte blocks)\n",
              change_count       => $self->{'change_count'},
              change_size_kbytes => _bytes_to_kbytes($self->{'change_size'}),
              total_count        => $self->{'total_count'},
              total_size_kbytes  => $self->{'total_size_kbytes'});
  }
  return 0;
}
sub _bytes_to_kbytes {
  my ($bytes) = @_;
  return POSIX::ceil($bytes/1024);
}

# return a list of the directory and all parent directories of $filename
sub parent_directories {
  my ($filename) = @_;
  my @ret;
  for (;;) {
    my $parent = File::Spec->rel2abs(File::Basename::dirname($filename));
    last if $parent eq $filename;
    push @ret, $parent;
    $filename = $parent;
  }
  return @ret;
}

#------------------------------------------------------------------------------
sub do_config_file {
  my ($self) = @_;
  my $config_filename = $self->config_filename;
  if ($self->{'verbose'} >= 2) {
    print __x("config: {filename}\n",
              filename => $config_filename);
  }
  if ($self->{'dry_run'}) {
    if ($self->{'verbose'}) { print __x("dry run\n"); }
  }
  require App::Upfiles::Conf;
  local $App::Upfiles::Conf::upf = $self;

  if (! defined (do { package App::Upfiles::Conf;
                      do $config_filename;
                    })) {
    if (! -e $config_filename) {
      croak __x("No config file {filename}",
                filename => $config_filename);
    } else {
      croak $@;
    }
  }
}
sub config_filename {
  my ($self) = @_;
  return $self->{'config_filename'} // do {
    require File::HomeDir;
    my $homedir = File::HomeDir->my_home
      // croak __('No home directory for config file (File::HomeDir)');
    return File::Spec->catfile ($homedir, $self->CONFIG_FILENAME);
  };
}

#------------------------------------------------------------------------------

sub ftp {
  my ($self) = @_;
  return ($self->{'ftp'} ||= do {
    require App::Upfiles::FTPlazy;
    App::Upfiles::FTPlazy->new (verbose => $self->{'verbose'});
  });
}

sub ftp_connect {
  my ($self) = @_;
  my $ftp = $self->ftp;
  $ftp->ensure_all
    or croak __x("ftp error on {hostname}: {ftperr}",
                 hostname => $ftp->host,
                 ftperr => $ftp->message);
}


# return ($mtime, $size) of last send of $filename to url $remote
sub db_get_mtime {
  my ($self, $dbh, $remote, $filename) = @_;
  my $sth = $dbh->prepare_cached
    ('SELECT mtime,size FROM sent WHERE remote=? AND filename=?');
  my $aref = $dbh->selectall_arrayref($sth, undef, $remote, $filename);
  $aref = $aref->[0] || return; # if no rows
  my ($mtime, $size) = @$aref;
  $mtime = timestamp_to_timet($mtime);
  return ($mtime, $size);
}

sub db_set_mtime {
  my ($self, $dbh, $remote, $filename, $mtime, $size) = @_;
  if ($self->{'verbose'} >= 2) {
    print "  database write $filename time=$mtime,size=$size\n";
  }
  $mtime = timet_to_timestamp($mtime);
  my $sth = $dbh->prepare_cached
    ('INSERT OR REPLACE INTO sent (remote,filename,mtime,size)
      VALUES (?,?,?,?)');
  $sth->execute ($remote, $filename, $mtime, $size);
}

sub db_delete_mtime {
  my ($self, $dbh, $remote, $filename) = @_;
  if ($self->{'verbose'} >= 2) {
    print "  database delete $filename\n";
  }
  my $sth = $dbh->prepare_cached
    ('DELETE FROM sent WHERE remote=? AND filename=?');
  $sth->execute ($remote, $filename);
}

sub db_remote_filenames {
  my ($dbh, $remote) = @_;
  my $sth = $dbh->prepare_cached
    ('SELECT filename FROM sent WHERE remote=?');
  return @{$dbh->selectcol_arrayref($sth, undef, $remote)};
}

sub dbh {
  my ($self, $db_filename) = @_;

  if ($self->{'verbose'} >= 2) {
    print "database open $db_filename\n";
  }

  require DBD::SQLite;
  my $dbh = DBI->connect ("dbi:SQLite:dbname=$db_filename",
                          '', '', {RaiseError=>1});
  $dbh->func(90_000, 'busy_timeout');  # 90 seconds

  {
    my ($dbversion) = do {
      local $dbh->{RaiseError} = undef;
      local $dbh->{PrintError} = undef;
      $dbh->selectrow_array
        ("SELECT value FROM extra WHERE key='database-schema-version'")
      };
    $dbversion ||= 0;
    if ($dbversion < $self->DATABASE_SCHEMA_VERSION) {
      $self->_upgrade_database ($dbh, $dbversion, $db_filename);
    }
  }
  return $dbh;
}

sub _upgrade_database {
  my ($self, $dbh, $dbversion, $db_filename) = @_;

  if ($dbversion <= 0) {
    if ($self->{'verbose'}) { print __x("initialize {filename}\n",
                                        filename => $db_filename); }

    $dbh->do (<<'HERE');
CREATE TABLE extra (
    key    TEXT  NOT NULL  PRIMARY KEY,
    value  TEXT
)
HERE
    $dbh->do (<<'HERE');
CREATE TABLE sent (
    remote    TEXT     NOT NULL,
    filename  TEXT     NOT NULL,
    mtime     TEXT     NOT NULL,
    size      INTEGER  NOT NULL,
    PRIMARY KEY (remote, filename)
)
HERE
  }

  $dbh->do ("INSERT OR REPLACE INTO extra (key,value)
             VALUES ('database-schema-version',?)",
            undef,
            $self->DATABASE_SCHEMA_VERSION);
}


#------------------------------------------------------------------------------
sub upfiles {
  my ($self, %option) = @_;

  if ($self->{'verbose'} >= 3) {
    require Data::Dumper;
    print Data::Dumper->new([\%option],['option'])->Sortkeys(1)->Dump;
  }
  my $local_dir  = $option{'local'} // croak __('No local directory specified');

  my $remote = $option{'remote'} // croak __('No remote target specified');
  require URI;
  my $remote_uri = URI->new($remote);
  my $remote_dir = $remote_uri->path;
  local $self->{'host'} = $remote_uri->host;
  local $self->{'username'} = $remote_uri->user;

  my @exclude_regexps = (@{$self->{'exclude_regexps_default'}},
                         @{$option{'exclude_regexps'} // []});
  if ($self->{'verbose'} >= 3) {
    print "exclude regexps\n";
    foreach my $re (@exclude_regexps) { print "  $re\n"; }
  }

  my @exclude_basename_regexps = (@{$self->EXCLUDE_BASENAME_REGEXPS_DEFAULT},
                                  @{$option{'exclude_basename_regexps'} // []});
  if ($self->{'verbose'} >= 3) {
    print "exclude basename regexps\n";
    foreach my $re (@exclude_basename_regexps) { print "  $re\n"; }
  }

  if ($self->{'verbose'}) {
    # TRANSLATORS: any need to translate this? maybe the -> arrow
    print __x("{localdir} -> {username}\@{hostname} {remotedir}\n",
              localdir  => $local_dir,
              username  => $self->{'username'},
              hostname  => $self->{'host'},
              remotedir => $remote_dir);
  }

  my $ftp = $self->ftp;
  ($ftp->host ($self->{'host'})
   && $ftp->login ($self->{'username'})
   && $ftp->binary)
    or croak __x("ftp error on {hostname}: {ftperr}",
                 hostname => $self->{'host'},
                 ftperr   => $self->ftp->message);

  # go to the directory to notice if it doesn't exist, before attempting to
  # open/create the database
  chdir $local_dir
    or croak __x("Cannot chdir to local directory {localdir}: {strerror}",
                 localdir => $local_dir,
                 strerror => "$!");

  my $db_filename = File::Spec->catfile ($local_dir, $self->DATABASE_FILENAME);
  my $dbh = $self->dbh ($db_filename);

  {
    # initial creation of remote dir
    my ($remote_mtime, $remote_size)
      = $self->db_get_mtime ($dbh, $option{'remote'}, '/');
    if (! $remote_mtime) {
      my $unslashed = $remote_dir;
      $unslashed =~ s{/$}{};
      if ($self->{'verbose'}) { print __x("MKD toplevel  {dirname}\n",
                                          dirname => $remote_dir); }

      unless ($self->{'dry_run'}) {
        $self->ftp_connect;
        $self->ftp->mkdir ($unslashed, 1)
          // croak __x("Cannot make directory {dirname}: {ftperr}",
                       dirname => $remote_dir,
                       ftperr  => $self->ftp->message);
      }
      $self->db_set_mtime ($dbh, $option{'remote'}, '/', 1, 1);
    }
  }
  $ftp->cwd ($remote_dir);

  require File::Find;
  my %local_filenames = ('/' => 1);
  my $wanted = sub {
    my $fullname = $File::Find::name;
    my $basename = File::Basename::basename ($fullname);

    if ($basename eq $self->DATABASE_FILENAME
        # ".upfiles.sqdb-journal" file if interrupted on previous run
        || $basename eq $self->DATABASE_FILENAME.'-journal') {
      $File::Find::prune = 1;
      return;
    }
    foreach my $exclude (@{$option{'exclude'}}) {
      if ($basename eq $exclude) {
        $File::Find::prune = 1;
        return;
      }
    }
    foreach my $re (@exclude_basename_regexps) {
      if (defined $re && $basename =~ $re) {
        $File::Find::prune = 1;
        return;
      }
    }
    foreach my $re (@exclude_regexps) {
      if (defined $re && $fullname =~ $re) {
        $File::Find::prune = 1;
        return;
      }
    }

    my $st = File::stat::stat($fullname)
      || croak __x("Cannot stat {filename}: {strerror}",
                   filename => $fullname,
                   strerror => $!);
    $self->{'total_size_kbytes'} += _bytes_to_kbytes($st->size);
    $self->{'total_count'}++;

    my $relname = File::Spec->abs2rel ($fullname, $local_dir);
    return if $relname eq '.';
    if (-d $fullname) {
      $relname .= '/';
    }

    $local_filenames{$relname} = 1;
  };
  File::Find::find ({ wanted => $wanted,
                      no_chdir => 1,
                      preprocess => sub { sort @_ },
                    },
                    $local_dir);
  ### %local_filenames

  my $any_changes = 0;
  foreach my $filename (sort keys %local_filenames) {
    if (my $action_files_hash = $self->{'action_files_hash'}) {
      my $filename_abs = File::Spec->rel2abs($filename);
      ### $filename_abs
      if (! exists $action_files_hash->{$filename_abs}) {
        next;
      }
      ### included in action_files_hash ...
    }

    if ($self->{'verbose'} >= 2) {
      print __x("local: {filename}\n", filename => $filename);
    }
    my $isdir = ($filename =~ m{/$});

    my ($remote_mtime, $remote_size)
      = $self->db_get_mtime ($dbh, $option{'remote'}, $filename);
    my $local_st = File::stat::stat($filename)
      // next; # if no longer exists
    my $local_mtime = ($isdir ? 1 : $local_st->mtime);
    my $local_size  = ($isdir ? 1 : $local_st->size);

    if ($self->{'verbose'} >= 2) {
      print "  local time=$local_mtime,size=$local_size ",
        "remote time=",$remote_mtime//'undef',",size=",$remote_size//'undef',"\n";
    }

    if (defined $remote_mtime && $remote_mtime == $local_mtime
        && defined $remote_size && $remote_size == $local_size) {
      if ($self->{'verbose'} >= 2) {
        print __x("    unchanged\n");
      }
      next;
    }

    unless ($self->{'nosend'}) {
      if ($isdir) {
        # directory, only has to exist
        my $unslashed = $filename;
        $unslashed =~ s{/$}{};
        if ($self->{'verbose'}) {
          print __x("MKD  {dirname}\n",
                    dirname => $filename);
        }
        $self->{'change_count'}++;
        $any_changes = 1;
        next if $self->{'dry_run'};

        $self->ftp_connect;
        $self->ftp->mkdir ($unslashed, 1)
          // croak __x("Cannot make directory {dirname}: {ftperr}",
                       dirname => $filename,
                       ftperr => $self->ftp->message);

      } else {
        # file, must exist and same modtime
        my $size_bytes = -s $filename;
        if ($self->{'verbose'}) {
          my $size_kbytes = max (0.1, $size_bytes/1024);
          $size_kbytes = sprintf('%.*f',
                                 ($size_kbytes >= 10 ? 0 : 1), # decimals
                                 $size_kbytes);
          print __x("PUT  {filename} [{size_kbytes}k]\n",
                    filename    => $filename,
                    size_kbytes => $size_kbytes);
        }
        $self->{'change_count'}++;
        $self->{'change_size'} += $size_bytes;
        $any_changes = 1;
        next if $self->{'dry_run'};

        my $tmpname = "$filename.tmp.$$";
        if ($self->{'verbose'} >= 2) {
          print "  with tmpname $tmpname\n";
        }
        $self->db_set_mtime ($dbh, $option{'remote'}, $tmpname,
                             $local_mtime, $local_size);

        {
          $self->ftp_connect;
          my $put;
          if (my $throttle_options = $option{'throttle'}) {
            require App::Upfiles::Tie::Handle::Throttle;
            require Symbol;
            my $fh = Symbol::gensym();
            tie *$fh, 'App::Upfiles::Tie::Handle::Throttle',
              %$throttle_options;
            ### tied: $fh
            ### tied: tied($fh)
            open $fh, '<', $filename
              or croak __x("Cannot open {filename}: {strerror}",
                           filename => $filename,
                           strerror => $!);
            $self->ftp->alloc ($local_size);
            $put = $self->ftp->put ($fh, $tmpname);
            close $fh
              or croak __x("Error closing {filename}: {strerror}",
                           filename => $filename,
                           strerror => $!);
          } else {
            $put = $self->ftp->put ($filename, $tmpname);
          }
          $put or croak __x("Error sending {filename}: {ftperr}",
                            filename => $filename,
                            ftperr   => $self->ftp->message);
        }

        if ($self->{'verbose'} >= 2) {
          print "  now rename\n";
        }
        $self->ftp->rename ($tmpname, $filename)
          or croak __x("Cannot rename {filename}: {ftperr}",
                       filename => $tmpname,
                       ftperr   => $self->ftp->message);
        $self->db_delete_mtime ($dbh, $option{'remote'}, $tmpname);
      }
    }
    $self->db_set_mtime ($dbh, $option{'remote'}, $filename,
                         $local_mtime, $local_size);
  }

  # reversed to delete contained files before their directory ...
  foreach my $filename (reverse db_remote_filenames($dbh, $option{'remote'})) {
    next if $local_filenames{$filename};
    if (my $action_files_hash = $self->{'action_files_hash'}) {
      if (! exists $action_files_hash->{$filename}) {
        next;
      }
    }
    my $isdir = ($filename =~ m{/$});

    if ($isdir) {
      my $unslashed = $filename;
      $unslashed =~ s{/$}{};
      if ($self->{'verbose'}) { print __x("RMD  {filename}\n",
                                          filename => $filename); }
      $self->{'change_count'}++;
      $any_changes = 1;
      next if $self->{'dry_run'};

      $self->ftp_connect;
      $self->ftp->rmdir ($unslashed, 1)
        or warn "Cannot rmdir $unslashed: ", $self->ftp->message;

    } else {
      if ($self->{'verbose'}) { print __x("DELE {filename}\n",
                                          filename => $filename); }
      $self->{'change_count'}++;
      $any_changes = 1;
      next if $self->{'dry_run'};

      $self->ftp_connect;
      $self->ftp->delete ($filename)
        or warn "Cannot delete $filename: ", $self->ftp->message;
    }
    $self->db_delete_mtime ($dbh, $option{'remote'}, $filename);
  }

  $ftp->all_ok
    or croak __x("ftp error on {hostname}: {ftperr}",
                 hostname => $self->{'host'},
                 ftperr   => $self->ftp->message);

  if (! $any_changes) {
    if ($self->{'verbose'}) { print '  ',__('no changes'),"\n"; }
  }

  return 1;
}


#------------------------------------------------------------------------------
# misc helpers

# # return size of $filename in kbytes
# sub file_size_kbytes {
#   my ($filename) = @_;
#   return _bytes_to_kbytes(-s $filename);
# }

# return st_mtime of $filename
sub stat_mtime {
  my ($filename) = @_;
  my $st = File::stat::stat($filename) // return;
  return $st->mtime;
}

# $st is a File::stat.  Return the disk space occupied by the file, based on
# the file size rounded up to the next whole block.
#  my $blksize = $st->blksize || 1024;
sub st_space {
  my ($st) = @_;
  my $blksize = 1024;
  require Math::Round;
  return scalar (Math::Round::nhimult ($blksize, $st->size));
}

sub timet_to_timestamp {
  my ($t) = @_;
  return POSIX::strftime ('%Y-%m-%d %H:%M:%S+00:00', gmtime($t));
}
sub timestamp_to_timet {
  my ($timestamp) = @_;
  my ($year, $month, $day, $hour, $minute, $second)
    = split /[- :+]/, $timestamp;
  require Time::Local;
  return Time::Local::timegm
    ($second, $minute, $hour, $day, $month-1, $year-1900);
}

1;
__END__

=for stopwords Upfiles Ryde

=head1 NAME

App::Upfiles -- upload files to an FTP server, for push mirroring

=head1 SYNOPSIS

 use App::Upfiles;
 exit App::Upfiles->command_line;

=head1 FUNCTIONS

=over 4

=item C<< $upf = App::Upfiles->new (key => value, ...) >>

Create and return an Upfiles object.

=item C<< $exitcode = App::Upfiles->command_line >>

=item C<< $exitcode = $upf->command_line >>

Run an Upfiles as from the command line.  Arguments are taken from C<@ARGV>
and the return is an exit status code suitable for C<exit>, meaning 0 for
success.

=back

=head1 SEE ALSO

L<upfiles>

=head1 HOME PAGE

L<http://user42.tuxfamily.org/upfiles/index.html>

=head1 LICENSE

Copyright 2009, 2010, 2011, 2012 Kevin Ryde

Upfiles is free software; you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software
Foundation; either version 3, or (at your option) any later version.

Upfiles is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License along with
Upfiles.  If not, see L<http://www.gnu.org/licenses/>.

=cut
