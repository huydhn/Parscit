package ParsCit::Tr2crfpp;

###
# Created from templateAppl.pl version 3.4 by Min-Yen Kan <kanmy@comp.nus.edu.sg>.
# Modified by Isaac Councill on 7/20/07: wrapped the code as a package for use by
# an external controller.
#
# Copyright 2005 \251 by Min-Yen Kan (not sure what this means for IGC edits, but
# what the hell -IGC)
###

use utf8;
use strict 'vars';

use FindBin;
use Encode ();
use ParsCit::Config;

### USER customizable section
my $tmp_dir		= $ParsCit::Config::tmpDir;
$tmp_dir		= "$FindBin::Bin/../$tmp_dir";

my $dict_file	= $ParsCit::Config::dictFile;
$dict_file		= "$FindBin::Bin/../$dict_file";

my $crf_test	= $ParsCit::Config::crf_test;
$crf_test		= "$FindBin::Bin/../$crf_test";

my $model_file	= $ParsCit::Config::modelFile;
$model_file		= "$FindBin::Bin/../$model_file";
### END user customizable section

###
# Huydhn: don't know its function
###
my %dict = ();

# Prepare data for trfpp
sub prepData 
{
    my ($rcite_text, $filename) = @_;

	# Generate a temporary file
    my $tmpfile = buildTmpFile($filename);

	print $tmpfile, "\n";

	###
	# Thang Mar 10: move inside the method, only load when running
	###
    readDict($dict_file); 

    unless (open(TMP, ">:utf8", $tmpfile)) 
	{
		fatal("Could not open tmp file " . $tmp_dir . "/" . $tmpfile . " for writing.");
      	return;
    }

    foreach (split "\n", $$rcite_text) 
	{	
		# Skip blank lines
		if (/^\s*$/) { next; }

		my $tag		= "";
		my @tokens	= split(/ +/);
		my @feats	= ();
		
		###
		# Modified by Artemy Kolchinsky (v090625): 'ed.' also matches things like 'Med.', 
		# which are found extremely often in my document database. To avoid this situation, 
		# I changed this string to match 'ed.', 'editor', 'editors', and 'eds.' if *not* 
		# preceeded by an alphabetic character.
		###
		my $has_possible_editor = (/[^A-Za-z](ed\.|editor|editors|eds\.)/) ? "possibleEditors" : "noEditors";

		my $j = 0;
		for (my $i = 0; $i <= $#tokens; $i++) 
		{
	    	if ($tokens[$i] =~ /^\s*$/) { next; }

			###
			# Thang v100401: /^\<\/([\p{IsLower}]+)/)
			###
	    	if ($tokens[$i] =~ /^<\/[a-zA-Z]+/) { next; }
			
			###
			# Thang v100401: /^\<([\p{IsLower}]+)/)
			###
	    	if ($tokens[$i] =~ /^<([a-zA-Z]+)/) 
			{
				$tag = $1;
				next;
	    	}

	    	# Prep
	    	my $word	= $tokens[$i];
			
			# No punctuation
	    	my $word_np	 = $tokens[$i];			      
	    	$word_np	 =~ s/[^\w]//g;
	    	if ($word_np =~ /^\s*$/) { $word_np	= "EMPTY"; }

			# Lowercased word, no punctuation
			my $word_lc_np	= lc($word_np);    
	    	if ($word_lc_np	=~ /^\s*$/) { $word_lc_np = "EMPTY"; }

	    	# Feature generation

			# 0 = lexical word	# 20 = possible editor

	    	$feats[ $j ][ 0 ] = $word;

	    	my @chars = split(//, $word);

	    	my $last_char = $chars[ -1 ];
	    	if ($last_char =~ /[\p{IsLower}]/) 
			{ 
				$last_char = 'a'; 
			}
	    	elsif ($last_char =~ /[\p{IsUpper}]/) 
			{ 
				$last_char = 'A'; 
			}
	    	elsif ($last_char =~ /[0-9]/) 
			{ 
				$last_char = '0'; 
			}

			# 1 = last char
			push(@{ $feats[ $j ] }, $last_char);

			# 2 = first char
			push(@{ $feats[ $j ] }, $chars[0]);

		    # 3 = first 2 chars
			push(@{ $feats[ $j ] }, join("", @chars[0..1]));

		    # 4 = first 3 chars
			push(@{ $feats[ $j ] }, join("", @chars[0..2]));

			# 5 = first 4 chars
	    	push(@{ $feats[ $j ] }, join("", @chars[0..3]));
			
			# 6 = last char
	    	push(@{ $feats[ $j ] }, $chars[-1]);
			
			# 7 = last 2 chars
	    	push(@{ $feats[ $j ] }, join("", @chars[-2..-1]));

			# 8 = last 3 chars
	    	push(@{ $feats[ $j ] }, join("", @chars[-3..-1]));

			# 9 = last 4 chars
		    push(@{ $feats[ $j ] }, join("", @chars[-4..-1]));

			# 10 = lowercased word, no punct
		    push(@{ $feats[ $j ] }, $word_lc_np);  

	    	# 11 - capitalization
	    	my $ortho = ($word_np =~ /^[\p{IsUpper}]$/) ? "singleCap" : 
						($word_np =~ /^[\p{IsUpper}][\p{IsLower}]+/) ? "InitCap" : 
						($word_np =~ /^[\p{IsUpper}]+$/) ? "AllCap" : "others";
	    	push(@{ $feats[ $j ] }, $ortho);

	    	# 12 - numbers
	    	my $num =	($word_np	=~ /^(19|20)[0-9][0-9]$/) ? "year" :
						($word		=~ /[0-9]\-[0-9]/) ? "possiblePage" :
						($word		=~ /[0-9]\([0-9]+\)/) ? "possibleVol" :
						($word_np	=~ /^[0-9]$/) ? "1dig" :
						($word_np	=~ /^[0-9][0-9]$/) ? "2dig" :
						($word_np	=~ /^[0-9][0-9][0-9]$/) ? "3dig" :
						($word_np	=~ /^[0-9]+$/) ? "4+dig" :
						($word_np	=~ /^[0-9]+(th|st|nd|rd)$/) ? "ordinal" :
						($word_np	=~ /[0-9]/) ? "hasDig" : "nonNum";
			push(@{ $feats[ $j ] }, $num);

	    	# Gazetteer (names)
	    	my $dict_status	= (defined $dict{ $word_lc_np }) ? $dict{ $word_lc_np } : 0;
	    	my $is_in_dict	= $dict_status;

	    	my ($publisher_name, $place_name, $month_name, $last_name, $female_name, $male_name);

	    	if ($dict_status >= 32) 
			{
				$dict_status	-= 32;
				$publisher_name	= "publisherName";
	    	} 
			else 
			{
				$publisher_name	= "no";
	    	}

	    	if ($dict_status >= 16) 
			{
				$dict_status	-= 16;
				$place_name		= "placeName";
	    	} 
			else 
			{
				$place_name		= "no";
	    	}

	    	if ($dict_status >= 8) 
			{
				$dict_status	-= 8;
				$month_name		= "monthName";
	    	} 
			else 
			{
				$month_name		= "no";
	    	}

	    	if ($dict_status >= 4) 
			{
				$dict_status	-= 4;
				$last_name		= "lastName";
	    	} 
			else 
			{
				$last_name		= "no";
	    	}

	    	if ($dict_status >= 2) 
			{
				$dict_status	-= 2;
				$female_name	= "femaleName";
	    	} 
			else 
			{
				$female_name	= "no";
	    	}
			
			if ($dict_status >= 1) 
			{
				$dict_status	-= 1;
				$male_name		= "maleName";
	    	} 
			else 
			{
				$male_name		= "no";
	    	}

			# 13 = name status
	    	push(@{ $feats[ $j ] }, $is_in_dict);

			# 14 = male name
			push(@{ $feats[ $j ] }, $male_name);

			# 15 = female name
			push(@{ $feats[ $j ] }, $female_name);
			
			# 16 = last name
	    	push(@{ $feats[ $j ] }, $last_name);

			# 17 = month name
	    	push(@{ $feats[ $j ] }, $month_name);

			# 18 = place name
	    	push(@{ $feats[ $j ] }, $place_name);
			
			# 19 = publisher name
	    	push(@{ $feats[ $j ] }, $publisher_name);

			# 20 = possible editor
	    	push(@{ $feats[ $j ] }, $has_possible_editor);

	    	# Not accurate ($#tokens counts tags too)
	    	if ($#tokens <= 0) { next; }

	    	my $location = int ($j / $#tokens * 12);
			
			# 21 = relative location
	    	push(@{ $feats[ $j ]}, $location);	      

	    	# 22 - punctuation
	    	my $punct =	($word	=~ /^[\"\'\`]/) ? "leadQuote" :
						($word	=~ /[\"\'\`][^s]?$/) ? "endQuote" :
						($word	=~ /\-.*\-/) ? "multiHyphen" :
						($word	=~ /[\-\,\:\;]$/) ? "contPunct" :
						($word	=~ /[\!\?\.\"\']$/) ? "stopPunct" :
						($word	=~ /^[\(\[\{\<].+[\)\]\}\>].?$/) ? "braces" :
						($word	=~ /^[0-9]{2-5}\([0-9]{2-5}\).?$/) ? "possibleVol" : "others";
		    # 22 = punctuation
			push(@{ $feats[ $j ] }, $punct);

		    # output tag
		    push(@{ $feats[ $j ] }, $tag);

	    	$j++;
		}

		# Export output: print
		for (my $j = 0; $j <= $#feats; $j++) 
		{
	    	print TMP join (" ", @{ $feats[ $j ] });
	    	print TMP "\n";
		}

		print TMP "\n";
    }
    close TMP;

	# Finish prepare data for crfpp
    return $tmpfile;
}

sub buildTmpFile 
{
    my ($filename) = @_;

    my $tmpfile	= $filename;
    $tmpfile	=~ s/[\.\/]//g;
    $tmpfile	.= $$ . time;

	# Untaint tmpfile variable
    if ($tmpfile =~ /^([-\@\w.]+)$/) { $tmpfile = $1; }
    
	###
	# Altered by Min (Thu Feb 28 13:08:59 SGT 2008)
	###
    return "/tmp/$tmpfile"; 
    # return $tmpfile;
}

sub fatal 
{
    my $msg = shift;
    print STDERR "Fatal Exception: $msg\n";
}


sub decode 
{
    my ($infile, $outfile) = @_;

    unless (open(PIPE, "$crf_test -m $model_file $infile |")) 
	{
		fatal("Could not open pipe from crf call: $!");
		return;
    }

    my $output;
    {
		local $/ = undef;
		$output = <PIPE>;
    }
    close PIPE;

    unless(open(IN, "<:utf8", $infile)) 
	{
		fatal("Could not open input file: $!");
		return;
    }

    my @code_lines = ();

	while(<IN>) 
	{
		chomp();
		push @code_lines, $_;
    }
    close IN;

    my @output_lines = split "\n", $output;
    for (my $i = 0; $i <= $#output_lines; $i++) 
	{
		# Remove blank line
		if ($output_lines[$i] =~ m/^\s*$/) { next; }
	
		my @output_tokens	= split " +", $output_lines[$i];
		my $class			= $output_tokens[ $#output_tokens ];
		my @code_tokens		= split "\t", $code_lines[ $i ];

		if ($#code_tokens < 0) { next; }

		$code_tokens[ $#code_tokens ] = $class;
		@code_lines[$i]	= join "\t", @code_tokens;
    }

    unless (open(OUT, ">:utf8", $outfile)) 
	{
		fatal("Could not open crf output file for writing: $!");
		return;
    }

    foreach my $line (@code_lines) 
	{
		###
		# Thang v100401: add this to avoid double decoding
		###
      	if (!Encode::is_utf8($line))
		{
			print OUT Encode::decode_utf8($line), "\n";
		} 
		else 
		{
			print OUT $line, "\n";
      	}
    }
    close OUT;

	return 1;
}

sub readDict 
{
	my $dict_file_loc = shift @_;

  	my $mode = 0;
  	open (DATA, "<:utf8", $dict_file_loc) || die "Could not open dict file $dict_file_loc: $!";
	
	while (<DATA>) 
	{
    	if		(/^\#\# Male/) 		{ $mode = 1; }		# male names
    	elsif	(/^\#\# Female/)	{ $mode = 2; }		# female names
    	elsif	(/^\#\# Last/)		{ $mode = 4; }		# last names
    	elsif	(/^\#\# Chinese/)	{ $mode = 4; }		# last names
    	elsif	(/^\#\# Months/)	{ $mode = 8; }		# month names
    	elsif	(/^\#\# Place/)		{ $mode = 16; }		# place names
    	elsif	(/^\#\# Publisher/)	{ $mode = 32; }		# publisher names
    	elsif	(/^\#/)				{ next; }
    	else 
		{
      		chop;
      		my $key = $_;
      		my $val = 0;

			# Has probability
			if (/\t/) { ($key, $val) = split (/\t/,$_); }

      		# Already tagged (some entries may appear in same part of lexicon more than once
			if ($dict{ $key } >= $mode) 
			{ 
				next; 
			}
			# not yet tagged
      		else 
			{ 
				$dict{$key} += $mode; 
			}
    	}
  	}

	close (DATA);
}

1;
