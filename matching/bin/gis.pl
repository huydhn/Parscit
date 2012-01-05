#!/usr/bin/perl -w

use strict;
use Getopt::Long;

use FindBin;
my $path;
BEGIN 
{
	if ($FindBin::Bin =~ /(.*)/) 
	{
		$path = $1;
	}
}

# Dependencies
use File::Spec;
use File::Basename;

use XML::Twig;

$0 =~ /([^\/]+)$/; 
my $progname = $1;

my $pattern	= undef; 
my $indir	= undef;

GetOptions(	'i=s'	=> \$indir,
			'p=s'	=> \$pattern );

if (! defined $indir) {
	exit(0);
}

# Name of the program which is used for clean up the name
my $clean_prog = "/home/salem/Local/bin/rclean";
# Name of the program which is used to compare the name
my $compare_prog = "/home/salem/Local/bin/rcompare";
# Name of the program which is used to canonicalize the name
my $canon_prog = "/home/salem/Local/bin/rcanonicalize";

# Genome Singapore
my %gis  = ();
# Not Genome Singapore
my %ngis = ();

# Countries
my %countries	= ();
# Places
my %places	 	= ();

# Geographical - overview
my %geo_all	= ();

# Read the dictionary
ReadDict("/home/salem/Local/wing/GAI/gsnap/resource/parscit.dic");

my @infiles = ();
GetFilesInDir($indir, \@infiles, $pattern);

foreach my $infile (@infiles) {
	print "# ", $infile, "\n";

	my $infile_abs	= File::Spec->rel2abs($infile);
	# Parse the input filename
	my ($filename, $directory, $suffix) = fileparse($infile, qr/\.[^.]*$/);

	# Get the Parscit result
	my ($aa, $ins) = GetParscit($directory . "/" . $filename . "-omni-parscit.xml");

	# Find author in Genome Singapore
	foreach my $author (keys %{ $aa }) {
		foreach my $aff (@{ $aa->{ $author } }) {
			my $afflc = lc $aff;
			my $autlc = lc $author;

			if ($afflc =~ m/genome.*?singapore/) {
				if (! exists $gis{ $autlc }) { $gis{ $autlc } = (); }

				# Save the author
				push @{ $gis{ $autlc } }, $aff;
			} else {
				if (! exists $ngis{ $autlc }) { $ngis{ $autlc } = (); }

				# Save the author
				push @{ $ngis{ $autlc } }, $aff;
			}
		}
	}
}

open my $gis_handle, ">:utf8", "gis-2005.csv";

# Unique names
my %unique_gis = ();

foreach my $author (keys %gis) {
	# Covert a name into it canonicalize form
	my $canon_name_short = `$canon_prog -i \"$author\" -m name -f 3`; chomp $canon_name_short;
	# Covert a name into it canonicalize form
	my $canon_name_long  = `$canon_prog -i \"$author\" -m name -f 2`; chomp $canon_name_long;
	# Save it as unique name
	if (! exists $unique_gis{ $canon_name_short }) { $unique_gis{ $canon_name_short } = (); }
	# Save it
	push @{ $unique_gis{ $canon_name_short } }, $canon_name_long;
}

foreach my $author (sort {$a cmp $b} keys %unique_gis) {
	print $gis_handle $author;

	# Possible name
	foreach my $name (@{ $unique_gis{ $author } }) {
		print $gis_handle ":", $name;
	}

	# Newline
	print $gis_handle "\n";
}

close $gis_handle;

open my $ngis_handle, ">:utf8", "ngis-2005.csv";

# Unique names
my %unique_ngis		= ();
# Affiliation
my %unique_ngis_aff	= ();

foreach my $author (keys %ngis) {
	# Covert a name into it canonicalize form
	my $canon_name_short = `$canon_prog -i \"$author\" -m name -f 3`; chomp $canon_name_short;

	# Covert a name into it canonicalize form
	my $canon_name_long  = `$canon_prog -i \"$author\" -m name -f 2`; chomp $canon_name_long;
	# Save it as unique name
	if (! exists $unique_ngis{ $canon_name_short }) { $unique_ngis{ $canon_name_short } = (); }
	# Save it
	push @{ $unique_ngis{ $canon_name_short } }, $canon_name_long;

	foreach my $aff (@{ $ngis{ $author } }) {
		# Save it
		if (! exists $unique_ngis_aff{ $canon_name_short }) { $unique_ngis_aff{ $canon_name_short } = (); }
		# Save it
		push @{ $unique_ngis_aff{ $canon_name_short } }, $aff;
	}
}

foreach my $author (sort {$a cmp $b} keys %unique_ngis) {
	print $ngis_handle $author;

	# Possible name
	foreach my $name (@{ $unique_ngis{ $author } }) {
		print $ngis_handle ":", $name;
	}

	# Possible affiliation 
	foreach my $aff (@{ $unique_ngis_aff{ $author } }) {
		print $ngis_handle ":", $aff;
	}

	# Newline
	print $ngis_handle "\n";
}

close $ngis_handle;

open my $geo_handle, ">:utf8", "geo-2005.csv";

# Unique place or country names
my %unique_loc = ();

foreach my $author (sort {$a cmp $b} keys %unique_ngis) {
	# Possible affiliation 
	foreach my $aff (@{ $unique_ngis_aff{ $author } }) {
		my @words = split /\s+/, $aff;
		
		my $found = 0;

		# Check each word against the dictionary
		for (my $i = 0; $i < scalar @words; $i++) {
			my $word = $words[ $i ] ;

			# Remove punctuation
			$word =~ s/[^\w]//g;
			# Lower case
			$word = lc $word;

			if (exists $countries{ $word }) {
				if (! exists $unique_loc{ $word }) { $unique_loc{ $word } = 0; }
				$unique_loc{ $word } += 1;
				$found = 1;
				last ;
			}
		}

		if ($found == 1) { next ;}

		# Check each word against the dictionary
		for (my $i = 0; $i < scalar @words; $i++) {
			my $word = $words[ $i ] ;

			# Remove punctuation
			$word =~ s/[^\w]//g;
			# Lower case
			$word = lc $word;

			if (exists $places{ $word }) {
				if (! exists $unique_loc{ $word }) { $unique_loc{ $word } = 0; }
				$unique_loc{ $word } += 1;
				$found = 1;
				last ;
			}
		}

	}

}

foreach my $place (sort {$a cmp $b} keys %unique_loc) {
	print $geo_handle $place, ":", $unique_loc{ $place }, "\n";
}

close $geo_handle;

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

sub GetParscit
{
	my ($infile) = @_;

	# Matching data will be stored here NAME => @{ INSTITUTE }
	my %aa  = () ;
	# Institution data will be stored here @{ INSTITUTE }
	my @ins = () ;

	# Parse XML output from Parscit
	my $parscit_roots		= { 'algorithms/algorithm'	=> 1 };

	# Each <algorithm> portion of parscit xml output will be handle by ParscitProcess func
	my $parscit_handlers	= { 'algorithms/algorithm'	=> sub { ParseParscit(@_, \%aa, \@ins); } };

	# XML::Twig 
	my $parscit_twig = new XML::Twig( twig_roots 	=> $parscit_roots,
								  	  twig_handlers	=> $parscit_handlers,
						 	 		  pretty_print	=> 'indented' );

	# Start the XML parsing
	$parscit_twig->parsefile($infile, \%aa, \@ins);
	$parscit_twig->purge;

	# Done
	return (\%aa, \@ins);
}

sub ParseParscit
{
	my ($twig, $node, $aa, $ins) = @_;

	# Care only for author affiliation extraction
	if ((! defined GetNodeAttr($node, "name")) || (GetNodeAttr($node, "name") ne "AAMatching")) { return ; }

	# The list of all authors and their affiliations
	my $child = $node->first_descendant("authors");
	# Is it exist?
	if (defined $child)
	{
		# The list of all authors and their affiliations
		my @authors	= $child->descendants("author");
		# Check author one by one
		foreach my $author (@authors)
		{
			# Get an author's fullname
			$child		 = $author->first_child("fullname");
			my $fullname = (defined $child) ? GetNodeText($child) : "";
			# Check for consistency
			if ($fullname eq "") { next ; }

			# Need to remove unsafe character
			$fullname =~ s/"|'|`//g;
			# Need to canonicalize the fullname
			my $canon_name = `$clean_prog -i \"$fullname\" -m name`; chomp $canon_name;

			# Skip blank name
			if ($canon_name eq '') { next ; } 
			
			# Get the list of corresponding institutions
			my @ins	= $author->first_child("institutions")->descendants("institution");
				
			if(! exists $aa->{ $canon_name }) { @{ $aa->{ $canon_name } } = (); };
			# Save the list of corresponding institutions
			foreach my $institute (@ins) {
				my $tmp = GetNodeText($institute);

				# Need to remove unsafe character
				$tmp =~ s/"|'|`//g;
				# Need to canonicalize the insitutional name
				my $canon_inst = `$clean_prog -i \"$tmp\" -m org`; chomp $canon_inst;
				
				if ($canon_inst ne '') {
					my %tmp = ();
					# Affiliation need to be unique
					foreach my $inst (@{ $aa->{ $canon_name } }) { $tmp{ $inst } = 0; }
					# Save the institution information
					if (! exists $tmp{ $canon_inst }) { push @{ $aa->{ $canon_name } }, $canon_inst; }
				}
			}
		}
	}

	$child = $node->first_child("results");
	# The list of institutions
	$child = (defined $child) ? $child->first_child("institutions") : undef;
	# Is it exists?
	if (defined $child) {
		# The list of institutions
		my @institutions = $child->descendants("institution");
	
		# Save the instituion one by one
		foreach my $institute (@institutions) {
			my $tmp = GetNodeText($institute);

			# Need to remove unsafe character
			$tmp =~ s/"|'|`//g;
			# Need to canonicalize the insitutional name
			my $canon_inst = `$clean_prog -i \"$tmp\" -m org`; chomp $canon_inst;
			
			if ($canon_inst ne '') {
				# Save the institution
				push @{ $ins }, $canon_inst;
			}
		}
	}

	# Cleanup
	$twig->purge;
}

sub GetNodeAttr 
{
	my ($node, $attr) = @_;
	return ($node->att($attr) ? $node->att($attr) : "");
}

sub SetNodeAttr 
{
	my ($node, $attr, $value) = @_;
	$node->set_att($attr, $value);
}

sub GetNodeText
{
	my ($node) = @_;
	return $node->text;
}

sub SetNodeText
{
	my ($node, $value) = @_;
	$node->set_text($value);
}

sub ReadDict
{
	my ($dictfile) = @_;

	my $dict_handle = undef;
	# Open the dictionary file from Parscit
  	open ($dict_handle, "<:utf8", $dictfile) || die "Could not open dict file $dictfile: $!";

	# Which dictionary is it?
	my $dict_pointer = undef;
	
	while (<$dict_handle>) 
	{
    	if		(/^\#\# Place/)		{ $dict_pointer = \%places; }		# Place names
    	elsif	(/^\#\# Country/) 	{ $dict_pointer = \%countries; }	# Country names
    	elsif	(/^\#/)				{ next; }
    	else 
		{
      		chop;
			
			# Words in dictionary
			my $key = $_;
			# Save
			$dict_pointer->{ $key } = 0;
    	}
  	}

	close ($dict_handle);
}


