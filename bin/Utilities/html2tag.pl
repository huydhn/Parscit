#!/usr/bin/perl -w

require 5.0;

use strict;
# Dependencies
use CGI;
use File::Spec;
use File::Basename;

use FindBin;
use Getopt::Long;

# Find the library path and the program name
my $path;
BEGIN 
{
	if ($FindBin::Bin =~ /(.*)/) 
	{
		$path = $1;
	}
}

# Library path
use lib $path . "/../lib";
# Program name
$0 =~ /([^\/]+)$/; my $progname = $1;

sub License 
{
	print STDERR "# Copyright 2011 \251 by Do Hoang Nhat Huy\n";
}

sub Help 
{
	print STDERR "Usage: $progname -h\t[invokes help]\n";
  	print STDERR "       $progname -in infile\n";
	print STDERR "Options:\n";
	print STDERR "\t-q  \tQuiet Mode (don't echo license).",  "\n";
	print STDERR "\t-in \tInput HTML.", "\n";
}

my $help	= 0;
my $quite	= 0;
my $infile	= undef;

$help = 1 unless GetOptions('in=s'		=> \$infile,
			 				'h' 		=> \$help,
							'q' 		=> \$quite);

if ($help || ! defined $infile)
{
	Help();
	exit(0);
}

if (! $quite) 
{
	License();
}

# Untaint check
$infile		= UntaintPath($infile);

# DEBUG
if (! $quite) { print $infile, "\n"; }

# Get the basename and the suffix
my ($filename, $directory, $suffix) = fileparse(File::Spec->rel2abs($infile), qr/\.[^.]*/);
# Call the preprocess execuatable
my $outfile = $directory . "/" . $filename . "-tagged.txt";
system($path . "/html2tag --in " . $infile . " --out " . $outfile);
	
my $handle	 = undef;
my $bcontent = undef;
# Decode html character
{
	open $handle, "<:utf8", $outfile;
	local $/ = undef; $bcontent = <$handle>;
	close $handle;
}
# by CGI
my $acontent = CGI::unescapeHTML($bcontent);
# Save to file
{
	open $handle, ">:utf8", $outfile;
	print $handle $acontent, "\n";
	close $handle;
}

# Support function
sub UntaintPath 
{
	my ($path) = @_;

	if ($path =~ /^([-_:" \/\w\.%\p{C}\p{P}]+)$/ ) 
	{
		$path = $1;
	} 
	else 
	{
		die "Bad path \"$path\"\n";
	}

	return $path;
}
















