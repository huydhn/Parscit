package Omni::Omnipage;

# Configuration
use strict;

# Local libraries
use Omni::Config;
use Omni::Omniword;
use Omni::Omnirun;
use Omni::Omniline;
use Omni::Omnipara;

# Extern libraries
use XML::Twig;
use XML::Parser;

# Global variables
my $tag_list = $Omni::Config::tag_list;
my $att_list = $Omni::Config::att_list;

# Temporary variables
my $tmp_content 	= undef;
my @tmp_paras		= ();

###
# A page object in Omnipage xml: a page contains zero or many collums or sections with many paragraphs
#
# Do Hoang Nhat Huy, 09 Jan 2011
###
# Initialization
sub new
{
	my ($class) = @_;

	# Lines: a paragraph can have multiple lines
	my @paras	= ();

	# Class members
	my $self = {	'_raw'			=> undef,
					'_content'		=> undef,
					'_paras'		=> \@paras	};

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

	# Copy all paragraphs
	@{$self->{ '_paras' } }	= @tmp_paras;
	
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
	$tmp_content 		= "";
	# because there's no paragraph
	@tmp_paras			= ();

	# Get <page> node attributes

	# Check if there's any para
	my @all_paras = $node->descendants( $tag_list->{ 'PARA' } );
	foreach my $pr (@all_paras)
	{
		my $para = new Omni::Omnipara();

		# Set raw content
		$para->set_raw($pr->sprint());

		# Update paragraph list
		push @tmp_paras, $para;

		# Update content
		$tmp_content = $tmp_content . $para->get_content() . "\n";
	}
}

sub get_paras_ref
{
	my ($self) = @_;
	return $self->{ '_paras' };
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
