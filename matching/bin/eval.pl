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
my $outdir	= undef;
my $mode	= undef;

GetOptions(	'i=s'	=> \$indir,
			'm=s'	=> \$mode,
			'p=s'	=> \$pattern );

if (! defined $indir) {
	exit(0);
}

if ((! defined $mode) || (($mode ne 'exact') && ($mode ne 'canon'))) {
	exit(0);
}

# Name of the program which is used for clean up the name
my $clean_prog = "/home/salem/Local/bin/rclean";
# Name of the program which is used to compare the name
my $compare_prog = "/home/salem/Local/bin/rcompare";
# Name of the program which is used to canonicalize the name
my $canon_prog = "/home/salem/Local/bin/rcanonicalize";

## BEGIN

my @infiles = ();
GetFilesInDir($indir, \@infiles, $pattern);

# Number of author discovered by Parscit
my $author_found		 = 0;
# Number of correct author discovered by Pascit
my $author_correct_found = 0;
# Number of correct author
my $author_true			 = 0;
# DEBUG
my %author_debug		 = ();

# Number of affiliation discovered by Parscit
my $affiliation_found	 	  = 0;
# Number of correct affiliation discovered by Parscit
my $affiliation_correct_found = 0;
# Number of correct affiliation
my $affiliation_true		  = 0;
# DEBUG
my %affiliation_debug		  = ();

# Number of author-affiliation discovered by Parscit
my $matching_found			= 0;
# Number of correct author-affiliation discovered by Parscit
my $matching_correct_found	= 0;
# Number of correct author-affiliation
my $matching_true			= 0;
# DEBUG
my %matching_debug			= ();

# List of Parscit output
foreach my $infile (@infiles) {
	print "# ", $infile, "\n";

	my $infile_abs	= File::Spec->rel2abs($infile);
	# Parse the input filename
	my ($filename, $directory, $suffix) = fileparse($infile, qr/\.[^.]*$/);

	# Get the ground truth
	my ($aa_truth, $ins_truth) = GetGroundTruth($directory . "/" . $filename . ".txt", $directory . "/" . $filename . "-aff.txt");

	# Get the Parscit result
	my ($aa, $ins) = GetParscit($directory . "/" . $filename . "-omni-parscit.xml");

	my $tmp = undef;

	# Get the number of correct author discovered by Parscit
	$tmp = CorrectAuthor($aa_truth, $aa); 
	$author_correct_found += $tmp;
	# Get the number of author discovered by Parscit
	$author_found += scalar(keys %{ $aa });
	# Get the correct number of author
	$author_true  += scalar(keys %{ $aa_truth});

	if ($tmp != scalar(keys %{ $aa_truth })) { 
		print "----------AUTHOR----------", "\n";
		foreach my $author (sort { $a cmp $b } keys %{ $aa }) {
			if (! exists $author_debug{ $author }) { print $author, "\n"; }
		}
		print "--------------------------", "\n";
		foreach my $author (sort { $a cmp $b } keys %{ $aa }) {
			print $author, "\n";
		}
		print "--------------------------", "\n";
		foreach my $author (sort { $a cmp $b } keys %{ $aa_truth }) {
			print $author, "\n";
		}
		print "--------------------------", "\n";
		print "\n";
	}

	# Get the number of correct affiliation discovered by Parscit
	$tmp = CorrectAffiliation($ins_truth, $ins);
	$affiliation_correct_found += $tmp;
	# Get the number of affiliation discovered by Parscit
	$affiliation_found += scalar(@{ $ins });
	# get the correct number of affiliation
	$affiliation_true  += scalar(@{ $ins_truth });

	if ($tmp != scalar(@{ $ins_truth })) { 
		print "---------AFFILIATION-------", "\n";
		foreach my $aff (sort { $a cmp $b } @{ $ins }) {
			if (! exists $affiliation_debug{ $aff }) { print $aff, "\n"; }
		}
		print "--------------------------", "\n";
		foreach my $aff (sort { $a cmp $b } @{ $ins }) {
			print $aff, "\n";
		}
		print "--------------------------", "\n";
		foreach my $aff (sort { $a cmp $b } @{ $ins_truth }) {
			print $aff, "\n";
		}
		print "--------------------------", "\n";
		print "\n";
	}
	
	# Get the number of correct author-affiliation discovered by Parscit
	$tmp = CorrectMatching($aa_truth, $aa);
	$matching_correct_found += $tmp;
	# Get the number of author-affiliation discovered by Parscit
	foreach my $author (keys %{ $aa }) { $matching_found += scalar @{ $aa->{ $author } }; }
	# Get the correct number of author-affiliation
	foreach my $author (keys %{ $aa_truth }) { $matching_true += scalar @{ $aa_truth->{ $author } }; }

	print "---------MATCHING---------", "\n";
	foreach my $author (sort { $a cmp $b } keys %{ $aa }) {
		foreach my $aff (sort { $a cmp $b } @{ $aa->{ $author } }) {
			if (! exists $matching_debug{ $author . "---" . $aff }) { print $author . "---" . $aff, "\n"; }
		}
	}
	print "--------------------------", "\n";
	foreach my $author (sort { $a cmp $b } keys %{ $aa }) {
		foreach my $aff (sort { $a cmp $b } @{ $aa->{ $author } }) {
			print $author . "---" . $aff, "\n";
		}
	}
	print "--------------------------", "\n";
	foreach my $author (sort { $a cmp $b } keys %{ $aa_truth }) {
		foreach my $aff (sort { $a cmp $b } @{ $aa_truth->{ $author } }) {
			print $author . "---" . $aff, "\n";
		}
	}
	print "--------------------------", "\n";
	print "\n";
}

# TOTAL
print "Total: ", scalar @infiles, " documents\n";

print "--------------------------------------\n";
print "----------------Author----------------\n";
print "--------------------------------------\n";

print "Author: ", $author_true, "\n";

my $precision = $author_correct_found / $author_found;
print "Precision: ", $precision * 100, "%", "\n";

my $recall = $author_correct_found / $author_true;
print "Recall   : ", $recall * 100, "%", "\n";

my $f1 = (2 * $precision * $recall) / ($precision + $recall);
print "F1       : ", $f1 * 100, "%", "\n";

print "--------------------------------------\n";
print "-------------Affiliation--------------\n";
print "--------------------------------------\n";

print "Affiliation: ", $affiliation_true, "\n";

$precision = $affiliation_correct_found / $affiliation_found;
print "Precision: ", $precision * 100, "%", "\n";

$recall = $affiliation_correct_found / $affiliation_true;
print "Recall   : ", $recall * 100, "%", "\n";

$f1 = (2 * $precision * $recall) / ($precision + $recall);
print "F1       : ", $f1 * 100, "%", "\n";

print "--------------------------------------\n";
print "---------------Matching---------------\n";
print "--------------------------------------\n";

print "Matching: ", $matching_true, "\n";

$precision = $matching_correct_found / $matching_found;
print "Precision: ", $precision * 100, "%", "\n";

$recall = $matching_correct_found / $matching_true;
print "Recall   : ", $recall * 100, "%", "\n";

$f1 = (2 * $precision * $recall) / ($precision + $recall);
print "F1       : ", $f1 * 100, "%", "\n";
## END

sub CorrectAuthor
{
	my ($aa_truth, $aa) = @_;

	# Number of correct author
	my $total = 0;

	foreach my $author (keys %{ $aa }) {
		if ($mode eq 'exact') {
			if (exists $aa_truth->{ $author }) { 
				$total += 1;
				
				# DEBUG
				$author_debug{ $author } = 0;
			}
		} elsif ($mode eq 'canon') {
			foreach my $true_author (keys %{ $aa_truth }) {
				# Need to compare these two names
				my $cmp_result = `$compare_prog -f \"$author\" -s \"$true_author\" -m name`; chomp $cmp_result;

				# A match is found
				if ($cmp_result eq '1') {
					# DEBUG
					$author_debug{ $author } = 0;

					$total += 1;
					last;
				}	
			}
		}
	}

	# Done
	return $total;
}

sub CorrectAffiliation
{
	my ($ins_truth, $ins) = @_;

	# Number of correct affiliation
	my $total = 0;
	
	foreach my $affiliation (@{ $ins }) {
		if ($mode eq 'exact') {
			foreach my $true_affiliation (@{ $ins_truth }) {
				# Need to compare these two names
				my $cmp_result = `$compare_prog -f \"$affiliation\" -s \"$true_affiliation\" -m org`; chomp $cmp_result;

				# A match is found
				if ($cmp_result eq '1') {						
					# DEBUG
					$affiliation_debug{ $affiliation } = 0;

					$total += 1;
					last ;
				}
			}
		} elsif ($mode eq 'canon') {
			my $canon_affiliation = `$canon_prog -i \"$affiliation\" -m org`; chomp $canon_affiliation;

			foreach my $true_affiliation (@{ $ins_truth }) {
				my $canon_true_affiliation = `$canon_prog -i \"$true_affiliation\" -m org`; chomp $canon_true_affiliation;

				# Need to compare these two names
				my $cmp_result = `$compare_prog -f \"$canon_affiliation\" -s \"$canon_true_affiliation\" -m org`; chomp $cmp_result;

				# A match is found
				if ($cmp_result eq '1') {
					# DEBUG
					$affiliation_debug{ $affiliation } = 0;

					$total += 1;
					last ;
				}
			}
		}

	}

	# Done
	return $total;
}

sub CorrectMatching
{
	my ($aa_truth, $aa) = @_;

	# Number of correct matching
	my $total = 0;

	foreach my $author (keys %{ $aa }) {
		if ($mode eq 'exact') {
			if (exists $aa_truth->{ $author }) { 			
				foreach my $affiliation (@{ $aa->{ $author } }) {
					foreach my $true_affiliation (@{ $aa_truth->{ $author } }) {
						# Need to compare these two names
						my $cmp_result = `$compare_prog -f \"$affiliation\" -s \"$true_affiliation\" -m org`; chomp $cmp_result;

						# A match is found
						if ($cmp_result eq '1') {
							# DEBUG
							$matching_debug{ $author . "---" . $affiliation } = 0;

							$total += 1;
							last ;
						}				
					}
				}			
			}
		} elsif ($mode eq 'canon') {			
			foreach my $true_author (keys %{ $aa_truth }) {
				# Need to compare these two names
				my $cmp_result = `$compare_prog -f \"$author\" -s \"$true_author\" -m name`; chomp $cmp_result;

				# A match is found
				if ($cmp_result eq '1') {										
					foreach my $affiliation(@{ $aa->{ $author } }) {					
						my $canon_affiliation = `$canon_prog -i \"$affiliation\" -m org`; chomp $canon_affiliation;

						foreach my $true_affiliation (@{ $aa_truth->{ $true_author } }) {
							my $canon_true_affiliation = `$canon_prog -i \"$true_affiliation\" -m org`; chomp $canon_true_affiliation;

							# Need to compare these two names
							my $cmp_result_aff = `$compare_prog -f \"$canon_affiliation\" -s \"$canon_true_affiliation\" -m org`; chomp $cmp_result_aff;

							# A match is found
							if ($cmp_result_aff eq '1') {
								# DEBUG
								$matching_debug{ $author . "---" . $affiliation } = 0;

								$total += 1;
								last ;
							}
						}
					}

					last ;
				}	
			}
		}
	}

	# Done
	return $total;
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

sub GetGroundTruth
{
	my ($infile, $aff_infile) = @_;

	# The truth
	my %aa_truth  = ();
	my @ins_truth = ();

	# Open the manually labelled ground truth
	open my $infile_handle, "<:utf8", $infile;
	
	# Each line is one author
	while(<$infile_handle>) {
		my $line = $_;
		# Trim
		$line =~ s/^\s+|\s+$//g;
		# Skip blank line
		if ($line eq '') { next; }
		
		# Split into multiple part
		my @parts = split /:/, $line;

		my $author = undef;
		# The first part is the author name
		$author = $parts[ 0 ];
		# Trim
		$author =~ s/^\s+|\s+$//g;

		# Remove all illegal character in the name
		$author =~ s/`|'|"//g;
		# Clean up the author name
		$author = `$clean_prog -i \"$author\" -m name`;		
		# Trim
		$author =~ s/^\s+|\s+$//g;
	
		my @affiliations = ();

		# All subsequent fields is affiliation
		for (my $i = 1; $i < scalar @parts; $i++) {
			my $aff = $parts[ $i ];
			# Trim
			$aff =~ s/^\s+|\s+$//g;

			# Remove all illegal character in the name
			$aff =~ s/`|'|"//g;
			# Clean up the author name
			$aff = `$clean_prog -i \"$aff\" -m org`;		
			# Trim
			$aff =~ s/^\s+|\s+$//g;

			# Save
			push @affiliations, $aff;
		}

		# Normalize - match with Parscit
		$author = NormalizeAuthorName($author);
		# Save the affliations
		$aa_truth{ $author } = \ @affiliations;
	}

	# Done
	close $infile_handle;

	# Open the manually labelled ground truth
	open my $aff_infile_handle, "<:utf8", $aff_infile;

	# Each line is one author
	while(<$aff_infile_handle>) {
		my $line = $_;
		# Trim
		$line =~ s/^\s+|\s+$//g;
		# Skip blank line
		if ($line eq '') { next; }

		# Trim
		$line =~ s/^\s+|\s+$//g;

		# Remove all illegal character in the name
		$line =~ s/`|'|"//g;
		# Clean up the author name
		$line = `$clean_prog -i \"$line\" -m org`;		
		# Trim
		$line =~ s/^\s+|\s+$//g;

		# Save
		push @ins_truth, $line;
	}

	# Done
	close $aff_infile_handle;

	# Done
	return (\ %aa_truth, \ @ins_truth);
}

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

sub NormalizeAuthorName 
{
    my ($name) = @_;

    $name =~ s/\.\-/-/g;
	$name =~ s/[\,\.]/ /g;
    $name =~ s/  +/ /g;
	$name =~ s/^\s+|\s+$//g;

    return $name;
}


