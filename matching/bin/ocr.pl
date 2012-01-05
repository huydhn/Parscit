#!/usr/bin/perl -w

use strict;
use Getopt::Long;

# Dependencies
use File::Spec;
use File::Basename;

$0 =~ /([^\/]+)$/; 
my $progname = $1;

my $pattern	= undef; 
my $indir	= undef;
my $outdir	= undef;

GetOptions(	'i=s'	=> \$indir,
			'o=s'	=> \$outdir,
			'p=s'	=> \$pattern );

if (!defined $indir || !defined $outdir) {
	exit(0);
}

## BEGIN

my @infiles = ();
GetFilesInDir($indir, \@infiles, $pattern);

foreach my $infile (@infiles) {
	print "# ", $infile, "\n";

	my $infile_abs	= File::Spec->rel2abs($infile);
	# Parse the input filename
	my ($filename, $directory, $suffix) = fileparse($infile, qr/\.[^.]*$/);
	# Output
	my $outfile_abs	= File::Spec->rel2abs($directory. "/" . $filename . "-omni.xml");
	# OCR
	system("ocr $infile_abs $outfile_abs xml tpe.ddns.comp.nus.edu.sg:31586");
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

