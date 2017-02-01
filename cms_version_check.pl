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

my @files;
my @directories;
my @directory_opts;

# Usage:
# perl cms_version_check.pl --directory wordpress
# supports multiple directories:
# perl cms_version_check.pl --directories html/blog --directory html/magazine
GetOptions(
    "directory=s" => \@directory_opts
) or die "Usage: perl $0 --directory dir1 [--directory dir2]";

# append current working directory to directory options otherwise
# relative directories (e.g. passed by tab completion aren't searched
my $cwd = cwd();
foreach my $directory (@directory_opts) {
    push(@directories, $directory);

    # this could go in an if statement, but lazy
    # e.g. if $directory doesn't exist, prepend $cwd
    push(@directories, "$cwd/$directory");
}
print Dumper(\@directories);

# theoretically, for multiple CMSs, it might be faster to do a
# @files = `find . -type f`
# that way, multiple find commands do not need to be run;
# stat'ing files and dirs is probably slow, compared to regex matching strings

# build array @files with list of matching file names. equivalent find command:
# find @directories -type f -path '*wp-includes*' -name 'version.php'
find(
    sub {
        if ( -f $File::Find::name
            && $File::Find::dir =~ m/wp-includes$/
            #&& $File::Find::name =~ m/version.php/
            && $_ eq 'version.php'
        )
        {
            print "$File::Find::dir\n";
            print "$File::Find::name\n";
            print "$_\n";
            push( @files, $File::Find::name );
        }
    },
    @directories
);

print Dumper(\@files);

# grep through each matching file for version data
foreach my $file (@files) {
    open my $fh, '<', $file or ERROR("Can't open file: " . $EVAL_ERROR);
    while (my $line = <$fh>) {
        chomp $line;

        # wp-version is stored like the following line:
        # $wp_version = '4.7.2';
        if ($line =~ m/^\$wp_version/) {
            print "$file\n$line\n";

            # last to skip reading rest of file
            last;
        }
    }
    close $fh;
}
