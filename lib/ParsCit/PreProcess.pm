package ParsCit::PreProcess;

###
# Utilities for finding and normalizing citations within
# text files, including separating citation text from
# body text and segmenting citations.
#
# Isaac Councill, 7/19/07
###

use strict;
use utf8;
use ParsCit::Citation;

my %marker_types =	(	'SQUARE'		=> '\\[.+?\\]',
		   				'PAREN'			=> '\\(.+?\\)',
		   				'NAKEDNUM'		=> '\\d+',
			   			'NAKEDNUMDOT'	=> '\\d+\\.',
						#'NAKEDNUM' 	=> '\\d{1,3}',		# Modified by Artemy Kolchinsky (v090625)
						#'NAKEDNUMDOT'	=> '\\d{1,3}\\.'	# Modified by Artemy Kolchinsky (v090625)
					);

###
# Looks for reference section markers in the supplied text and
# separates the citation text from the body text based on these
# indicators.  If it looks like there is a reference section marker
# too early in the document, this procedure will try to find later
# ones.  If the final reference section is still too long, an empty
# citation text string will be returned.  Returns references to
# the citation text, normalized body text, and original body text.
###
sub findCitationText 
{
    my ($rtext, $pos_array) = @_;

	# Save the text
	my $text		= $$rtext;
    my $bodytext	= '0';
    my $citetext	= '0';

	###
	# Corrected by Cheong Chi Hong <chcheong@cse.cuhk.edu.hk> 2 Feb 2010
	# while ($text =~ m/\b(References?|REFERENCES?|Bibliography|BIBLIOGRAPHY|References?\s+and\s+Notes?|References?\s+Cited|REFERENCE?\s+CITED|REFERENCES?\s+AND\s+NOTES?):?\s*\n+/sg) 
	# {
	###
    while ($text =~ m/\b(References?|REFERENCES?|Bibliography|BIBLIOGRAPHY|References?\s+and\s+Notes?|References?\s+Cited|REFERENCES?\s+CITED|REFERENCES?\s+AND\s+NOTES?):?\s*\n+/sg) 
	{
		$bodytext = substr $text, 0, pos $text;
		$citetext = substr $text, pos $text unless (pos $text < 1);
    }

	# Odd case: when citation is longer than the content itself, what should we do?
    if (length($citetext) >= 0.8 * length($bodytext)) 
	{
		$citetext = "";
		print STDERR "Citation text longer than article body: ignoring\n";
		return \$citetext, \normalizeBodyText(\$bodytext), \$bodytext;
    }

	# Citation stops when another section starts
    my ($scitetext, $tmp) = split(/^([\s\d\.]+)?(Acknowledge?ments?|Autobiographical|Tables?|Appendix|Exhibit|Annex|Fig|Notes?)(.*?)\n+/m, $citetext);

	if (length($scitetext) > 0) { $citetext = $scitetext; }

	# No citation exists
    if ($citetext eq '0' || ! defined $citetext) { print STDERR "warning: no citation text found\n"; }

	# Now we have the citation text
	return (normalizeCiteText(\$citetext), normalizeBodyText(\$bodytext, $pos_array), \$bodytext);
}

##
# Removes lines that appear to be junk from the citation text.
##
sub normalizeCiteText 
{
    my ($rcitetext) = @_;

    my @newlines	= ();
    my @lines		= split "\n", $$rcitetext;

	###
	# Modified by Artemy Kolchinsky (v090625)
	# In some cases, I had situations like:
	# Smith B, "Blah Blah." Journal1, 2000, p. 23-
	# 85
	# Here, the line consisting of '85' is part of the citation and shouldn't be dropped, 
	# even though it only consist of numeric characters.  The way I went about this is 
	# that I dropped those lines consisting of only spacing characters, *or* only numeric 
	# characters *if the previous line did not end on a hyphen*.
	###
    my $oldline = "";

	foreach my $line (@lines) 
	{
		$line =~ s/^\s*//g; # Dropped leading spaces added by Thang (v090625)
      	$line =~ s/\s*$//g; # Dropped trailing spaces added by Thang (v090625)
		
		if ($line =~ m/^\s*$/ || ($oldline !~ m/\-$/ && $line =~ m/^\d*$/)) 
		{
			$oldline = $line;
			next;
      	}

      	$oldline = $line;
      	push @newlines, $line;
    }
	###
	# End modified by Artemy Kolchinsky (v090625)
	###

    my $newtext = join "\n", @newlines;
    return \$newtext;
}

###
# Thang May 2010
# Address the problem Nick mentioned in method normalizeBodyText()
# This method handle multiple bracket references in a line, e.g "abc [1, 2-5, 11] def [1-3, 5] ghi jkl"
# + this method maps the position of tokens in normalized body text --> positions of tokens in body text (for later retrieve context positions)
###
sub expandBracketMarker 
{
	my ($line, $pos_array, $token_count) = @_;
  	#  $line = "abc [1, 2-5, 11] def [1-3, 5] ghi jkl";
  	#  $line = "abc[1, 2-5, 11]def[1-3, 5]ghi jkl";
  	#  $line = "abc def ghi jkl";

  	my $count		= 0;
  	my $front		= "";
  	my $match		= "";
  	my $remain		= $line;
  	my $newline		= "";
  	my $space_flag	= 0;

  	while($line =~ m/\[(\d+[,;] *)*((\d+)-(\d+))([,;] *\d+)*\]/g)
	{
    	$front	= $`;
    	$match	= $&;
    	$line	= $';
    
	    # Handle front part
    	if($space_flag == 1) { $newline .= " "; }
		$newline .= $front;

    	my @tokens	= split(/\s+/, $front);
    	my $length	= scalar(@tokens);
		
    	for(my $i=0; $i < $length; $i++)
		{
      		if($i < ($length -1) || $front =~ / $/) 
			{
				#print STDERR "$tokens[$i] --> ".$token_count."\n";
				push(@{ $pos_array }, $token_count++);
      		}
    	}
    
    	# Handle match part
    	my $num_new_tokens = 0;
    	if ($match =~ /^\[(\d+[,;] *)*((\d+)-(\d+))([,;] *\d+)*\]$/)
		{
      		$num_new_tokens = $4 - $3;
			if ($num_new_tokens > 0)
			{
				$match = "[" . $1 . transformMarker($3, $4) . $5 . "]";
      		} 
			else 
			{
				$num_new_tokens = 0;
      		}
    	}
    	$newline .= $match;
    
		my @tokens	= split(/\s+/, $match);
		my $length	= scalar(@tokens);
		
		for(my $i=0; $i < $length; $i++)
		{
      		if($i < ($length -1) || $line =~ /^ /) 
			{
				#print STDERR "$tokens[$i] --> ".$token_count."\n";
				if ($i >= ($length - $num_new_tokens-1) && $i < ($length -1))
				{
	  				push(@{ $pos_array }, $token_count);
				} 
				else 
				{
	  				push(@{ $pos_array }, $token_count++);
				}
      		}
    	}
    
    	if ($line =~ /^ /)
		{
      		$space_flag	= 1;
      		$line		=~ s/^\s+//;
    	} 
		else 
		{
      		$space_flag = 0;
    	}
    	
		$count++;
  	}
  
  	if($space_flag == 1) { $newline .= " "; }
	$newline .= $line;

  	my @tokens	= split(/\s+/, $line);
  	my $length	= scalar(@tokens);

  	for(my $i=0; $i < $length; $i++)
	{
		#print STDERR "$tokens[$i] --> ".$token_count."\n";
		push(@{ $pos_array }, $token_count++);
  	}

	return ($newline, $token_count);
}

###
# Removes lines that appear to be junk from the body text,
# de-hyphenates words where a hyphen occurs at the end of
# a line, and normalizes strings of blank spaces to only
# single blancks.
#
# HISTORY: Nick (v081201)
# 
# In some publications markers with a range such as [1-5] or [1-12, 16]
# are used. ParsCit cannot find these markers. I added a simple
# workaround to PreProcess::normalizeBodyText. The markers with range
# are replaced by markers containing every number of the range
# (e.g. [1-5] replaced by [1, 2, 3, 4, 5]).
###
sub normalizeBodyText 
{
	my ($rtext, $pos_array) = @_;

  	my @lines		= split "\n", $$rtext;
  	my $text		= "";
  	my $token_count	= 0;
	
	foreach my $line (@lines) 
	{
    	$line =~ s/^\s+//; # Thang May 2010: trip leading spaces

    	my @tmp_pos_array		= ();
		($line, $token_count)	= expandBracketMarker($line, \@tmp_pos_array, $token_count); # Thang May 2010
		my @tokens				= split(/\s+/, $line);
		
		if(scalar(@tokens) != scalar(@tmp_pos_array))
		{
      		die "scalar(@tokens) != scalar(@tmp_pos_array)\n$line\n";
    	}
		#$line =~ s/\[(\d+[,;] *)*((\d+)-(\d+))([,;] *\d+)*\]/"[".$1.transformMarker($3,$4).$5."]"/e;
    
		if ($line =~ m/^\s*$/) { next; }
    
		###
    	# Modified by Artemy Kolchinsky (v090625)
    	# !!! merge without removing "-" if preceeded by numbers...
		###
    	if ($text =~ s/([A-Za-z])\-$/$1/) 
		{
      		$text .= $line;
      		shift(@tmp_pos_array); 
    	} 
		else 
		{
      		if ($text !~ m/\-\s+$/ && $text ne "") { $text .= " " } # Thang May 2010: change m/\-\s*$/ -> m/\-\s+$/
      		$text .= $line;
    	}

    	push(@{$pos_array}, @tmp_pos_array);
		###
    	# End modified by Artemy Kolchinsky (v090625)
		###
  	}

  	$text =~ s/\s{2,}/ /g;
	return \$text;  
}

sub transformMarker 
{
	my ($first_number, $second_number) = @_;

	my $new_marker = $first_number;	
	for (my $i = ($first_number + 1) ; $i <= $second_number ; $i++) { $new_marker .= ", " . $i; }
	return $new_marker;
}

###
# Controls the process by which citations are segmented, based 
# on the result of trying to guess the type of citation marker 
# used in the reference section.  Returns a reference to a list 
# of citation objects.
###
sub segmentCitations 
{
    my ($rcite_text) = @_;

    my $marker_type = guessMarkerType($rcite_text);

    my $rcitations = undef;
    if ($marker_type ne 'UNKNOWN') 
	{
		$rcitations = splitCitationsByMarker($rcite_text, $marker_type);
    } 
	else 
	{
		$rcitations = splitUnmarkedCitations($rcite_text);
    }

    return $rcitations;
}


###
# Segments citations that have explicit markers in the
# reference section.  Whenever a new line starts with an
# expression that matches what we'd expect of a marker,
# a new citation is started.  Returns a reference to a
# list of citation objects.
###
sub splitCitationsByMarker 
{
    my ($rcite_text, $marker_type) = @_;

    my @citations 				= ();
    my $current_citation		= new ParsCit::Citation();
    my $current_citation_string	= undef;

    # TODO: Might want to add a check that marker number is
    # increasing as we'd expect, if the marker is numeric.

    foreach my $line (split "\n", $$rcite_text) 
	{
		if ($line =~ m/^\s*($marker_types{ $marker_type })\s*(.*)$/) 
		{
	    	my ($marker, $cite_string) = ($1, $2);
			
			if (defined $current_citation_string) 
			{
				$current_citation->setString($current_citation_string);
				push @citations, $current_citation;
				$current_citation_string = undef;
	    	}

	    	$current_citation			= new ParsCit::Citation();
			$current_citation->setMarkerType($marker_type);
	    	$current_citation->setMarker($marker);
			$current_citation_string	= $cite_string;
		} 
		else 
		{
			###
	  		# Modified by Artemy Kolchinsky (v090625)
	  		# !!! merge without removing "-" if preceeded by numbers...
			###
	  		if ($current_citation_string =~ m/[A-Za-z]\-$/)
			{
		    	# Merge words when lines are hyphenated
	    		$current_citation_string	=~ s/\-$//; 
	    		$current_citation_string	.= $line;
	  		} 
			else 
			{
	    		if ($current_citation_string !~ m/\-\s*$/) { $current_citation_string .= " "; } #!!!
	    		$current_citation_string .= $line;
			}
			###
	  		# End modified by Artemy Kolchinsky (v090625)
			###
		}
    }
    
	# Last citation
	if (defined $current_citation && defined $current_citation_string) 
	{
		$current_citation->setString($current_citation_string);
		push @citations, $current_citation;
    }

	# Now, we have an array of separated citations
    return \@citations;
}

###
# Replace heuristics rules with crf++ model based on both textual
# and XML features from Omnipage.
#
# HISTORY: Added in 100111 by Huy Do
###
sub splitUnmarkedCitations2
{

}

###
# Uses several heuristics to decide where individual citations
# begin and end based on the length of previous lines, strings
# that look like author lists, and punctuation.  Returns a
# reference to a list of citation objects.
#
# HISTORY: Modified in 081201 by Nick and J\"{o}ran.
# 
# There was an error with unmarkedCitations. ParsCit ignored the last
# citation in the reference section due to a simple error in a for loop.
# In PreProcess::splitUnmarkedCitations (line 241; line 258 in my
# modified file) "$k<$#citeStarts" is used as exit condition. It should
# be "<=" and not "<" beause $#citeStarts provides the last index and
# not the length of the array.
#
# HISTORY: Modified in 081201 by Min to remove superfluous print statements
###
sub splitUnmarkedCitations 
{
    my ($rcite_text) = @_;

    my @content		= split "\n", $$rcite_text;
    
	my $cite_start	= 0;
    my @cite_starts	= ();
    my @citations	= ();

	###
	# Huydhn: when a line is an author line (the line at the start of 
	# a citation with a long list of author), the next line cannot be
	# the start of another (consequence) citation. This next line should
	# be the next part of the current citation after the author line.
	###
	my $last_author_line = undef;

	for (my $i = 0; $i <= $#content; $i++) 
	{
		if ($content[ $i ] =~ m/\b\(?[1-2][0-9]{3}[\p{IsLower}]?[\)?\s,\.]*(\s|\b)/s) 
		{
	    	for (my $k = $i; $k > $cite_start; $k--) 
			{
				if ($content[ $k ] =~ m/\s*[\p{IsUpper}]/g) 
				{
					###
					# Huydhn: The previous line is an author line, so this line
					# cannot be the start of another citation
					if ($last_author_line == $k - 1) { next; }

		    		# If length of previous line is extremely
		    		# small, then start a new citation here.
		    		if (length($content[ $k - 1 ]) < 2) 
					{
						$cite_start = $k;
						last;
		    		}

		    		# Start looking backwards for lines that could
		    		# be author lists - these usually start the
		    		# citation, have several separation characters (,;),
		    		# and shouldn't contain any numbers.
		    		my $beginning_author_line = -1;

		    		for (my $j = $k - 1; $j > $cite_start; $j--) 
					{
						if ($content[ $j ] =~ m/\d/) { last; }
			
						$_			= $content[ $j ];
						my $n_sep	= s/([,;])/\1/g;

						if ($n_sep >= 3) 
						{
			    			if (($content[ $j - 1 ] =~ m/\.\s*$/) || $j == 0) 
							{
								$beginning_author_line = $j;
							}
						} 
						else 
						{
			    			last;
						}
		    		}
		    
					if ($beginning_author_line >= 0) 
					{
						$cite_start			= $beginning_author_line;

						###
						# Huydhn: see $last_author_line
						###
						$last_author_line	= $beginning_author_line;

						last;
		    		}

		    		# Now that the backwards author search failed
		    		# to find any extra lines, start a new citation
		    		# here if the previous line ends with a ".".

					###
		    		# Modified by Artemy Kolchinsky (v090625)
					# A new citation is started if the previous line ended with 
					# a period, but not if it ended with a period, something else, 
					# and then a period.  This is to avoid assuming that abbrevations, 
					# like U.S.A. , indicate the end of a cite.  Also, a new cite is 
					# started only if the current line does not begin with a series of 
					# 4 digits.  This helped avoid some mis-parsed citations for me.  
					# The new if-statement read like:
					###		   
		    		if ($content[ $k - 1 ] =~ m/[^\.].\.\s*$/ && $content[ $k ] !~ m/^\d\d\d\d/) 
					{
		      			$cite_start = $k;
		      			last;
		    		}
				}
	    	}   
	   		# End of for 
			
			push @cite_starts, $cite_start unless (($cite_start <= $cite_starts[ $#cite_starts ]) && ($cite_start != 0));
		}
    }

    for (my $k = 0; $k <= $#cite_starts; $k++) 
	{
		my $first_line	= $cite_starts[ $k ];
		my $last_line	= ($k == $#cite_starts) ? $#content : ($cite_starts[ $k + 1 ] - 1);

		my $cite_string	= mergeLines(join "\n", @content[ $first_line .. $last_line ]);
		
		my $citation	= new ParsCit::Citation();
		$citation->setString($cite_string);
		push @citations, $citation;
    }

	# And then from nothing came everything
    return \@citations;
}

###
# Merges lines of text by dehyphenating where appropriate,
# with normal spacing.
###
sub mergeLines 
{
    my ($text) = shift;

    my @lines		= split "\n", $text;
    my $merged_text	= "";

    foreach my $line (@lines) 
	{
		$line = trim($line);

		###
		# Modified by Artemy Kolchinsky (v090625)
		# # !!! merge without removing "-" if preceeded by numbers...
		###
		if ($merged_text =~ m/[A-Za-z]\-$/) 
		{
	  		# Merge words when lines are hyphenated
	  		$merged_text	=~ s/\-$//; 
	  		$merged_text	.= $line;
		} 
		else 
		{
	  		if ($merged_text !~ m/\-\s*$/) { $merged_text .= " " } #!!!
	  		$merged_text .= $line;
		}
		###
		# End modified by Artemy Kolchinsky (v090625)
		###
    }

    return trim($merged_text);
}

###
# Uses a list of regular expressions that match common citation
# markers to count the number of matches for each type in the
# text.  If a sufficient number of matches to a particular type
# are found, we can be reasonably sure of the type.
###
sub guessMarkerType 
{
    my ($rcite_text) = @_;

    my $marker_type			= 'UNKNOWN';
    my %marker_observations	= ();

    foreach my $type (keys %marker_types) 
	{
		$marker_observations{$type} = 0;
    }

    my $cite_text	= "\n" . $$rcite_text;
    $_ 				= $cite_text;
    my $n_lines		= s/\n/\n/gs - 1;

    while ($cite_text =~ m/\n\s*($marker_types{'SQUARE'}([^\n]){10})/sg) 
	{
		$marker_observations{'SQUARE'}++;
    }

    while ($cite_text =~ m/\n\s*($marker_types{'PAREN'}([^\n]){10})/sg) 
	{
		$marker_observations{'PAREN'}++;
    }
	
	###
	# Modified by Artemy Kolchinsky (v090625): remove space after {10})
	###
    while ($cite_text =~ m/\n\s*($marker_types{'NAKEDNUM'} [^\n]{10})/sg) 
	{ 
		$marker_observations{'NAKEDNUM'}++;
    }

    while ($cite_text =~ m/\n\s*$marker_types{'NAKEDNUMDOT'}([^\n]){10}/sg) 
	{
		$marker_observations{'NAKEDNUMDOT'}++;
    }

    my @sorted_observations = sort { $marker_observations{ $b } <=> $marker_observations{ $a } } keys %marker_observations;

    my $min_markers = $n_lines / 6;
    if ($marker_observations{ $sorted_observations[0] } >= $min_markers) 
	{
		$marker_type = $sorted_observations[0];
    }

    return $marker_type;
}

sub trim 
{
    my $text = shift;
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    return $text;
}

1;
