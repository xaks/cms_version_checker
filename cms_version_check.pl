#!/usr/bin/env perl

use strict;
use warnings;

use Cwd;
use Data::Dumper;
use English qw( -no_match_vars );
use File::Find;
#use File::Find::Rule;    # a nicer interface to File::Find, but not in core perl
use Getopt::Long qw(GetOptions);
use Log::Log4perl qw(:easy);

Log::Log4perl->easy_init($ERROR);

# Usage:
#   perl cms_version_check.pl --directory /path/to/wordpress
# supports relative path directories:
#   perl cms_version_check.pl --directories ./
# supports multiple directories:
#   perl cms_version_check.pl --directories html/blog --directory html/magazine
# supports short flags
#   perl cms_version_check.pl -d html

my @DIRECTORIES;
my @directory_opts;
my $USAGE = "Usage: perl $0 --directory dir1 [--directory dir2]";

GetOptions(
    "directory=s" => \@directory_opts
) or die $USAGE;

if (! scalar @directory_opts ) {
    die "no directory specified\n$USAGE";
}

# append current working directory to directory options otherwise
# relative directories (e.g. passed by tab completion aren't searched
my $cwd = cwd();
foreach my $directory (@directory_opts) {
    push(@DIRECTORIES, $directory);

    # this could go in an if statement, but lazy
    # e.g. if $directory doesn't exist, prepend $cwd
    push(@DIRECTORIES, "$cwd/$directory");
}
print Dumper(\@DIRECTORIES);

# theoretically, for multiple CMSs, it might be faster to do a
# @files = `find . -type f`
# that way, multiple find commands do not need to be run;
# stat'ing files and dirs is probably slow, compared to regex matching strings

# WordPress version info is stored like the following line:
# $wp_version = '4.7.2';
my $wordpress_search_opts = {
    path          => 'wp-includes',
    file          => 'version.php',
    search_string => '$wp_version',
};

# https://www.drupal.org/docs/7/choosing-a-drupal-version/overview
# Drupal 8 version info is stored like the following line:
# const VERSION = '8.2.5';
my $drupal_8_search_opts = {
    path          => 'core/lib',
    file          => 'Drupal.php',
    search_string => 'const VERSION',
};

my @cms_targets = ( $wordpress_search_opts, $drupal_8_search_opts );
print Dumper(@cms_targets);

foreach my $search_opts (@cms_targets) {
    my @files = find_files($search_opts);
    #print Dumper(\@files);
    version_search(\@files, $search_opts);
}

sub find_files {
    my ($search_opts) = @_;

    my $file_path = $search_opts->{path};
    my $file_name = $search_opts->{file};

    my @found_files;

    # build array @files with list of matching file names. equivalent find command:
    # find @directories -type f -path '*wp-includes*' -name 'version.php'
    find(
        sub {
            if ( -f $File::Find::name
                && $File::Find::dir =~ m/$file_path$/
                #&& $File::Find::name =~ m/version.php/
                && $_ eq "$file_name"
            )
            {
                #print "$File::Find::dir\n";
                #print "$File::Find::name\n";
                #print "$_\n";
                push( @found_files, $File::Find::name );
            }
        },
        @DIRECTORIES
    );
    return @found_files;
}

sub version_search {
    my ($files, $search_opts) = @_;

    my $search_string = $search_opts->{search_string};

    # grep through each matching file for version data
    foreach my $file (@{$files}) {
        open my $fh, '<', $file or ERROR("Can't open file: " . $EVAL_ERROR);
        while (my $line = <$fh>) {
            #print $line;
            chomp $line;

            if ($line =~ m/^\Q$search_string\E/) {
                print "$file\n$line\n";

                # last to skip reading rest of file
                last;
            }
        }
        close $fh;
    }
}
