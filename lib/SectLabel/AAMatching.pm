package SectLabel::AAMatching;

###
# This package provides methods to solve the matching problem
# between author and affiliation in a pdf
#
# Do Hoang Nhat Huy 21 Apr, 11
###

use strict;

# Dictionary
my %dict = ();

# Author
# Affiliation
sub AAMatching
{
	my ($doc, $aut_addrs, $aff_addrs) = @_;

	my $need_object	= 1;
	# Get the author objects
	my $aut_lines	= Omni::Traversal::OmniCollector($doc, $aut_addrs, $need_object);
	# Get the affiliation objects
	my $aff_lines	= Omni::Traversal::OmniCollector($doc, $aff_addrs, $need_object);
	
	# Dictionary
	ReadDict($SectLabel::Config::dictFile);
	# DEBUG
	AuthorFeatureExtraction($aut_lines);
}

# Extract features from author lines
# The list of feature include
# Content
# Content, lower case, no punctuation
# Capitalization
# Numeric property
# Last punctuation
# First 4-gram
# Last 4-gram
# Dictionary
# First word in line
#
# XML features
# Subscript, superscript
# Bold
# Italic
# Underline
# Relative font size
# Differentiate features
sub AuthorFeatureExtraction
{
	my ($aut_lines) = @_;
	
	# Features will be stored here
	my $features 		= "";
	# First word in line
	my $is_first_line	= undef;
	# First word in run
	# my $is_first_run	= undef;

	# Font size
	my %fonts = ();
	# Each line contains many runs
	foreach my $line (@{ $aut_lines })
	{
		my $runs = $line->get_objs_ref();
		# Iterator though all work in all lines
		foreach my $run (@{ $runs })
		{
			my $fsize = $run->get_font_size();
			my $words = $run->get_objs_ref();

			# Statistic
			if (! exists $fonts{ $fsize })
			{
				$fonts{ $fsize } = scalar(@{ $words });
			}
			else
			{
				$fonts{ $fsize } += scalar(@{ $words });
			}
		}
	}

	my $dominate_font = undef;
	# Sort all the font descend with the number of their appearance
	my @sorted = sort { $fonts{ $b } <=> $fonts{ $a } } keys %fonts;
	# Select the dominated font
	$dominate_font = @sorted[ 0 ];

	# Each line contains many runs
	foreach my $line (@{ $aut_lines })
	{
		# Set first word in line
		$is_first_line = 1;

		# Format of the previous word
		my ($prev_bold, $prev_italic, $prev_underline, $prev_suscript, $prev_fontsize) = "unknown";

		my $runs = $line->get_objs_ref();
		# Iterator though all work in all lines
		foreach my $run (@{ $runs })
		{
			# The run must be non-empty
			my $tmp = $run->get_content();
			# Trim
			$tmp	=~ s/^\s+|\s+$//g;
			# Skip blank run
			if ($tmp eq "") { next; }

			# Set first word in run
			# $is_first_run = 1; 

			###
			# The following features are XML features
			###
			
			# Bold format	
			my $bold = ($run->get_bold() eq "true") ? "bold" : "none";
			
			# Italic format	
			my $italic = ($run->get_italic() eq "true") ? "italic" : "none";

			# Underline
			my $underline = ($run->get_underline() eq "true") ? "underline" : "none";

			# Sub-Sup-script
			my $suscript =	($run->get_suscript() eq "superscript")	? "super"	:
							($run->get_suscript() eq "subscript")	? "sub"		: "none";

			# Relative font size
			my $fontsize =	($run->get_font_size() > $dominate_font)	? "large"	:
							($run->get_font_size() < $dominate_font)	? "small"	: "normal";
			
			###
			# End of XML features
			###

			# All words in the run
			my $words = $run->get_objs_ref();

			# For each word
			foreach my $word (@{ $words })
			{
				# Extract features
				my $content = $word->get_content();
				# Trim
				$content	=~ s/^\s+|\s+$//g;

				# Skip blank run
				if ($content eq "") { next; }

				# Content
				$features .= $content . "\t";
			
				# Remove punctuation
				my $content_n	=~ s/[^\w]//g;
				# Lower case
				my $content_l	= lc($content);
				# Lower case, no punctuation
				my $content_nl	= lc($content_n);
				# Lower case
				$features .= $content_l . "\t";
				# Lower case, no punctuation
				if ($content_nl ne "")
				{
					$features .= $content_nl . "\t";
				}
				else
				{
					$features .= $content_l . "\t";
				}

				# Capitalization
				my $ortho = ($content =~ /^[\p{IsUpper}]$/)					? "single"	:
							($content =~ /^[\p{IsUpper}][\p{IsLower}]+/)	? "init" 	:
							($content =~ /^[\p{IsUpper}]+$/) 				? "all" 	: "others";
				$features .= $ortho . "\t";

				# Numeric property
				my $num =	($content =~ /^[0-9]$/)					? "1dig" 	:
							($content =~ /^[0-9][0-9]$/) 			? "2dig" 	:
							($content =~ /^[0-9][0-9][0-9]$/) 		? "3dig" 	:
							($content =~ /^[0-9]+$/) 				? "4+dig" 	:
							($content =~ /^[0-9]+(th|st|nd|rd)$/)	? "ordinal"	:
							($content =~ /[0-9]/) 					? "hasdig" 	: "nonnum";
				$features .= $num . "\t";

				# Last punctuation
				my $punct = ($content =~ /^[\"\'\`]/) 						? "leadq" 	:
							($content =~ /[\"\'\`][^s]?$/) 					? "endq" 	:
	  						($content =~ /\-.*\-/) 							? "multi"	:
	    					($content =~ /[\-\,\:\;]$/) 					? "cont" 	:
	      					($content =~ /[\!\?\.\"\']$/) 					? "stop" 	:
	        				($content =~ /^[\(\[\{\<].+[\)\]\}\>].?$/)		? "braces" 	: "others";
				$features .= $punct . "\t";

				# Split into character
	      		my @chars = split(//, $content);
				# First n-gram
				$features .= $chars[ 0 ] . "\t";
				$features .= join("", @chars[ 0..1 ]) . "\t";
				$features .= join("", @chars[ 0..2 ]) . "\t";
				$features .= join("", @chars[ 0..3 ]) . "\t";
      			# Last n-gram
				$features .= $chars[ -1 ] . "\t";
				$features .= join("", @chars[ -2..-1 ]) . "\t";
				$features .= join("", @chars[ -3..-1 ]) . "\t";
				$features .= join("", @chars[ -4..-1 ]) . "\t";
			
				# Dictionary
				my $dict_status = (defined $dict{ $content_nl }) ? $dict{ $content_nl } : 0;
				# Possible names
				my ($publisher_name, $place_name, $month_name, $last_name, $female_name, $male_name) = undef;
   				# Check all case 
				if ($dict_status >= 32) { $dict_status -= 32; 	$publisher_name	= "publisher"	} else { $publisher_name	= "no"; }
	    		if ($dict_status >= 16)	{ $dict_status -= 16; 	$place_name 	= "place" 		} else { $place_name 		= "no"; }
	    		if ($dict_status >= 8)	{ $dict_status -= 8; 	$month_name 	= "month" 		} else { $month_name 		= "no"; }
    			if ($dict_status >= 4)	{ $dict_status -= 4; 	$last_name 		= "last" 		} else { $last_name 		= "no"; }
	    		if ($dict_status >= 2) 	{ $dict_status -= 2; 	$female_name 	= "female" 		} else { $female_name 		= "no"; }
    			if ($dict_status >= 1) 	{ $dict_status -= 1; 	$male_name 		= "male" 		} else { $male_name 		= "no"; }
	    		# Save the feature
				$features .= $male_name 	 . "\t";
				$features .= $female_name 	 . "\t";
				$features .= $last_name 	 . "\t";
				$features .= $month_name 	 . "\t";
				$features .= $place_name 	 . "\t";
				$features .= $publisher_name . "\t";

				# First word in line
				if ($is_first_line == 1)
				{
					$features .= "begin" . "\t";
	
					# Next words are not the first in line anymore
					$is_first_line = 0;
				}
				else	
				{
					$features .= "continue" . "\t";
				}		

				###
				# The following features are XML features
				###
			
				# Bold format	
				$features .= $bold . "\t";
			
				# Italic format	
				$features .= $italic . "\t";

				# Underline
				$features .= $underline . "\t";

				# Sub-Sup-script
				$features .= $suscript . "\t";

				# Relative font size
				$features .= $fontsize . "\t";

				# First word in run
				if (($prev_bold ne $bold) || ($prev_italic ne $italic) || ($prev_underline ne $underline) || ($prev_suscript ne $suscript) || ($prev_fontsize ne $fontsize))
				{
					$features .= "fbegin" . "\t";
	
					# Next words are not the first in line anymore
					# $is_first_run = 0;
				}
				else	
				{
					$features .= "fcontinue" . "\t";
				}

				# New token
				$features .= "\n";

				# Save the XML format
				$prev_bold		= $bold;
				$prev_italic	= $italic;
				$prev_underline	= $underline;
				$prev_suscript	= $suscript;
				$prev_fontsize	= $fontsize;
			}			
		}
	}

	print $features;
}

sub ReadDict 
{
  	my ($dictfile) = @_;

	my $dict_handle = undef;
  	open ($dict_handle, "<:utf8", $dictfile) || die "Could not open dict file $dictfile: $!";

	my $mode = 0;
  	while (<$dict_handle>) 
	{
    	if (/^\#\# Male/) 			{ $mode = 1; }		# male names
    	elsif (/^\#\# Female/) 		{ $mode = 2; }		# female names
    	elsif (/^\#\# Last/) 		{ $mode = 4; }		# last names
    	elsif (/^\#\# Chinese/) 	{ $mode = 4; }		# last names
    	elsif (/^\#\# Months/) 		{ $mode = 8; }		# month names
    	elsif (/^\#\# Place/) 		{ $mode = 16; }		# place names
    	elsif (/^\#\# Publisher/)	{ $mode = 32; }		# publisher names
    	elsif (/^\#/) { next; }
    	else 
		{
      		chop;
      		my $key = $_;
      		my $val = 0;
			# Has probability
      		if (/\t/) { ($key,$val) = split (/\t/,$_); }

      		# Already tagged (some entries may appear in same part of lexicon more than once
      		if (! exists $dict{ $key })
			{
				$dict{ $key } = $mode;
      		} 
			else 
			{
				if ($dict{ $key } >= $mode) 
				{ 
					next; 
				}
				# Not yet tagged
				else 
				{ 
					$dict{ $key } += $mode; 
				}
      		}
    	}
  	}
  
	close ($dict_handle);
}

1;

















