#!/usr/bin/perl

# Author: Do Hoang Nhat Huy <huydo@comp.nus.edu.sg>
# Modified from template by Min-Yen Kan <kanmy@comp.nus.edu.sg>

require 5.0;
use strict;

# Dependencies
use FindBin;
use Getopt::Long;
# SVM implemenation
use Algorithm::SVM;
use Algorithm::SVM::DataSet;

# I do not know a better solution to find a lib path in -T mode.
# So if you know a better solution, I'd be glad to hear.
# See this http://www.perlmonks.org/?node_id=585299 for why I used the below code

# To get correct path in case 2 scripts in different directories use FindBin
FindBin::again(); 
my $path = undef;
BEGIN 
{
	if ($FindBin::Bin =~ /(.*)/) { $path = $1; }
}
use lib "$path/../../lib";

### USER customizable section
$0 =~ /([^\/]+)$/; my $progname = $1;
my $version = "1.0";
### END user customizable section

sub License 
{
	print STDERR "# Copyright 2011 \251 by Do Hoang Nhat Huy\n";
}

sub Help 
{
	print STDERR "Build the SVM model from training data for author / affiliation matching\n";
	print STDERR "usage: $progname -h\t[invokes help]\n";
	print STDERR "       $progname -i tagged data -o SVM model\n";
	print STDERR "Options:\n";
	print STDERR "\t-q      \tQuiet Mode (don't echo license)\n";
}

my $quite	= 0;
my $help	= 0;
my $outfile	= undef;
my $infile	= undef;

$help = 1 unless GetOptions(	'i=s'	=> \$infile,
								'o=s' 	=> \$outfile,
								'h'		=> \$help,
								'q'		=> \$quite	);

if ($help || ! defined $infile || ! defined $outfile) 
{
	Help();
  	exit(0);
}

if (!$quite) 
{
	License();
}

### Untaint ###
$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';
### End untaint ###

# Dataset
my @svm_train_data = ();

# New SVM 
my $svm = new Algorithm::SVM();

my $input_handle = undef;
# Read the CRF output
open $input_handle, "<:utf8", $infile;
# Read each line and get its label
while (<$input_handle>) {
	my $line = $_;
	# Trim
	$line =~ s/^\s+|\s+$//g;
	# Blank line, what the heck ?
	if ($line eq "") { next; }

	# Split the line
	my @fields	= split /\t/, $line;

	# Checking
	if (9 != scalar(@fields)) { print STDERR $line, "\n"; die; }
	
	# Extract the content
	my $content	 = $fields[ 0 ];
	# The signal
	my $same_sig = $fields[ 1 ];
	# Same page
	my $same_pag = $fields[ 2 ];
	# Same section
	my $same_sec = $fields[ 3 ];
	# Same paragraph
	my $same_par = $fields[ 4 ];
	# Same line
	my $same_lin = $fields[ 5 ];
	# Nearest in x-axis
	my $near_x	 = $fields[ 6 ];
	# Nearest in y-axis
	my $near_y	 = $fields[ 7 ];
	# Label
	my $label	 = $fields[ 8 ];

	# New data point
	my $ds = new Algorithm::SVM::DataSet(	Label => 0,
       		                              	Data  => [ 0, 0, 0, 0, 0, 0, 0 ]	);

	# Set label first
	if ($label eq 'yes') {
		$ds->label(1);	
	} else {
		$ds->label(0);
	}

	# Set signal feature
	if ($same_sig eq 'same') {
		$ds->attribute(0, 1);
	} else {
		$ds->attribute(0, 0);
	}
		
	# Set same page feature
	if ($same_pag eq 'yes') {
		$ds->attribute(1, 1);
	} else {
		$ds->attribute(1, 0);
	}

	# Set same section feature
	if ($same_sec eq 'yes') {
		$ds->attribute(2, 1);
	} else {
		$ds->attribute(2, 0);
	}

	# Set same paragraph feature
	if ($same_par eq 'yes') {
		$ds->attribute(3, 1);
	} else {
		$ds->attribute(3, 0);
	}

	# Set same line feature
	if ($same_lin eq 'yes') {
		$ds->attribute(4, 1);
	} else {
		$ds->attribute(4, 0);
	}

	# Nearest x
	if ($near_x eq 'yes') {
		$ds->attribute(5, 1);
	} else {
		$ds->attribute(5, 0);
	}

	# Nearest y
	if ($near_y eq 'yes') {
		$ds->attribute(6, 1);
	} else {
		$ds->attribute(6, 0);
	}

	# Save the data point
	push @svm_train_data, $ds;
}

# Done
close $input_handle;

# Training in process
$svm->train(@svm_train_data);
	
# Done
$svm->save($outfile);


