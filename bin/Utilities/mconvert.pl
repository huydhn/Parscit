#!/usr/bin/perl -w

use strict;
use Getopt::Long;

# Dependencies
use File::Spec;
use File::Basename;


$0 =~ /([^\/]+)$/; 
my $progname = $1;

sub Help 
{
	print STDERR "Usage: $progname -h\t[invokes help]\n";
  	print STDERR "       $progname -i indir -o outdir -f from -t to -p pattern\n";
	print STDERR "Options:\n";
	print STDERR "\t-i	\tFiles in \"from\" format.\n";
	print STDERR "\t-o	\tFiles in \"to\" format.\n";
	print STDERR "\t-f	\tFormat.\n";
	print STDERR "\t-t	\tFormat.\n";
	print STDERR "\t-p	\tFiles pattern.\n";
}

my $help	= 0;
my $from	= 0;
my $to		= 0;
my $pattern	= undef; 
my $indir	= undef;
my $outdir	= undef;

$help = 1 unless GetOptions('i=s'	=> \$indir,
			 				'o=s'	=> \$outdir,
							'f=s'	=> \$from,
							't=s'	=> \$to,
							'p=s'	=> \$pattern,
			 				'h' 	=> \$help	);

if ($help || !defined $indir || !defined $outdir) 
{
	Help();
	exit(0);
}

## BEGIN

my @infiles = ();
GetFilesInDir($indir, \@infiles, $pattern);

foreach my $infile (@infiles)
{
	print $infile, "\n";

	my $infile_abs	= File::Spec->rel2abs($infile);
	# Parse the input filename
	my ($filename, $directory, $suffix) = fileparse($infile, qr/\.[^.]*$/);
	# Output
	my $outfile_abs	= File::Spec->rel2abs($outdir . "/" . $filename . "-utf8" . $suffix);
	# Convert
	Convert($infile_abs, $from, $outfile_abs, $to);
}

## END

sub GetFilesInDir
{
	my ($indir, $files, $pattern) = @_;

	# Insane
	if(! -d $indir) { die "Die: directory $indir does not exist!\n"; }
  	# Insane
	if(! defined $pattern) { $pattern = ""; }

  	my $line	= `find $indir -type f`;
	my @tokens	= split(/\s+/, $line);

	my @tmp_files = ();
	foreach my $token (@tokens)
	{
    	if ($token ne "" && $token !~ /^\.$/ && $token !~ /^\.\.$/ && $token !~ /~$/ && $token =~ /$pattern/){ push(@tmp_files, $token); }
	}

	@{ $files } = sort { $a cmp $b } @tmp_files;
}

sub Convert
{
	my ($from_file, $from_encode, $to_file, $to_encode) = @_;
	
	# Call iconv program
	my $cmd = "iconv" . " -f " . $from_encode . " -t " . $to_encode . " " . $from_file . " -o " . $to_file;
	
	# Transformation
	system($cmd);
}







