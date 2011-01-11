package Omni::Omnipage;

# Configuration
use strict;

# Local libraries
use Omni::Config;
use Omni::Omniword;
use Omni::Omnirun;
use Omni::Omniline;
use Omni::Omnipara;
use Omni::Omnicol;

# Extern libraries
use XML::Twig;
use XML::Parser;

# Global variables
my $tag_list = $Omni::Config::tag_list;
my $att_list = $Omni::Config::att_list;

# Temporary variables
my $tmp_content 	= undef;
my @tmp_cols		= ();

###
# A page object in Omnipage xml: a page contains zero or many collums
#
# Do Hoang Nhat Huy, 09 Jan 2011
###
# Initialization
sub new
{
	my ($class) = @_;

	# Page: a page can have many columns
	my @cols	= ();

	# Class members
	my $self = {	'_raw'			=> undef,
					'_content'		=> undef,
					'_cols'			=> \@cols	};

	bless $self, $class;
	return $self;
}

# 
sub set_raw
{
	my ($self, $raw) = @_;

	# Save the raw xml <page> ... </page>
	$self->{ '_raw' }	= $raw;

	# Parse the raw string
	my $twig_roots		= { $tag_list->{ 'PAGE' }	=> 1 };
	my $twig_handlers 	= { $tag_list->{ 'PAGE' }	=> \&parse};

	# XML::Twig 
	my $twig = new XML::Twig(	twig_roots 		=> $twig_roots,
						 	 	twig_handlers	=> $twig_handlers,
						 	 	pretty_print 	=> 'indented'	);

	# Start the XML parsing
	$twig->parse($raw);
	$twig->purge;

	# Copy information from temporary variables to class members

	# Copy all columns 
	@{$self->{ '_cols' } }	= @tmp_cols;
	
	# Copy content
	$self->{ '_content' }	= $tmp_content;
}

sub get_raw
{
	my ($self) = @_;
	return $self->{ '_raw' };
}

sub parse
{
	my ($twig, $node) = @_;

	# At first, content is blank
	$tmp_content	= "";
	# because there's no column
	@tmp_cols		= ();

	# Get <page> node attributes

	# Check if there's any column 
	my @all_cols = $node->descendants( $tag_list->{ 'COLUMN' } );
	foreach my $cl (@all_cols)
	{
		my $column = new Omni::Omnicol();

		# Set raw content
		$column->set_raw($cl->sprint());

		# Update column list
		push @tmp_cols, $column;

		# Update content
		$tmp_content = $tmp_content . $column->get_content() . "\n";
	}
}

sub get_cols_ref
{
	my ($self) = @_;
	return $self->{ '_cols' };
}

sub get_content
{
	my ($self) = @_;
	return $self->{ '_content' };
}

# Support functions
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

1;
