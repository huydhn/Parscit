package Omni::Omniline;

# Configuration
use strict;

# Local libraries
use Omni::Config;
use Omni::Omniword;
use Omni::Omnirun;

# Extern libraries
use XML::Twig;
use XML::Parser;
use XML::Writer;
use XML::Writer::String;

# Global variables
my $tag_list = $Omni::Config::tag_list;
my $att_list = $Omni::Config::att_list;

# Temporary variables
my $tmp_content 	= undef;
my $tmp_baseline	= undef;
my $tmp_bottom		= undef;
my $tmp_top			= undef;
my $tmp_left		= undef;
my $tmp_right		= undef;
my @tmp_runs		= ();

###
# A line object in Omnipage xml: a line can contain one or many runs
#
# Do Hoang Nhat Huy, 09 Jan 2011
###
# Initialization
sub new
{
	my ($class) = @_;

	# Runs: a line can have multiple runs
	my @runs	= ();

	# Class members
	my $self = {	'_raw'			=> undef,
					'_content'		=> undef,
					'_baseline'		=> undef,
					'_bottom'		=> undef,
					'_top'			=> undef,
					'_left'			=> undef,
					'_right'		=> undef,
					'_bullet'		=> undef,
					'_runs'			=> \@runs	};

	bless $self, $class;
	return $self;
}

# 
sub set_raw
{
	my ($self, $raw) = @_;
	
	# Save the raw xml <ln> ... </ln>
	$self->{ '_raw' }	= $raw;

	# Parse the raw string
	my $twig_roots		= { $tag_list->{ 'LINE' }	=> 1 };
	my $twig_handlers 	= { $tag_list->{ 'LINE' }	=> \&parse};

	# XML::Twig 
	my $twig = new XML::Twig(	twig_roots 		=> $twig_roots,
						 	 	twig_handlers	=> $twig_handlers,
						 	 	pretty_print 	=> 'indented'	);

	# Start the XML parsing
	$twig->parse($raw);
	$twig->purge;

	# Copy information from temporary variables to class members
	$self->{ '_baseline' }	= $tmp_baseline;
	$self->{ '_bottom' }	= $tmp_bottom;
	$self->{ '_top' }		= $tmp_top;
	$self->{ '_left' }		= $tmp_left;
	$self->{ '_right' } 	= $tmp_right;
	
	# Copy all runs
	@{ $self->{ '_runs' } }	= @tmp_runs;

	# Copy content
	$self->{ '_content' } 	= $tmp_content;
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
	# because there's no run
	@tmp_runs			= ();

	# Get <line> node attributes
	$tmp_bottom		= GetNodeAttr($node, $att_list->{ 'BOTTOM' });
	$tmp_top		= GetNodeAttr($node, $att_list->{ 'TOP' });
	$tmp_left		= GetNodeAttr($node, $att_list->{ 'LEFT' });
	$tmp_right		= GetNodeAttr($node, $att_list->{ 'RIGHT' });
	$tmp_baseline	= GetNodeAttr($node, $att_list->{ 'BASELINE' });
	
	# Get <line> node possible attributes
	my $tmp_font_face	= GetNodeAttr($node, $att_list->{ 'FONTFACE' });
	my $tmp_font_family	= GetNodeAttr($node, $att_list->{ 'FONTFAMILY' });
	my $tmp_font_pitch	= GetNodeAttr($node, $att_list->{ 'FONTPITCH' });
	my $tmp_font_size	= GetNodeAttr($node, $att_list->{ 'FONTSIZE' });
	my $tmp_spacing		= GetNodeAttr($node, $att_list->{ 'SPACING' });
	my $tmp_su_script	= GetNodeAttr($node, $att_list->{ 'SUSCRIPT' });	# sub-script or super-script
	my $tmp_underline	= GetNodeAttr($node, $att_list->{ 'UNDERLINE' });
	my $tmp_bold		= GetNodeAttr($node, $att_list->{ 'BOLD' });
	my $tmp_italic		= GetNodeAttr($node, $att_list->{ 'ITALIC' });

	# Check if there's any run
	my @all_runs = $node->descendants( $tag_list->{ 'RUN' });
	# There is not
	if ((! defined @all_runs) || (scalar(@all_runs) == 0))
	{
		my $output = XML::Writer::String->new();
		my $writer = new XML::Writer(OUTPUT => $output, UNSAFE => 'true');

		# Form the fake <run>
		$writer->startTag(	"run", 
							$att_list->{ 'FONTFACE' } 	=> $tmp_font_face,
							$att_list->{ 'FONTFAMILY' }	=> $tmp_font_family,
							$att_list->{ 'FONTPITCH' } 	=> $tmp_font_pitch,
							$att_list->{ 'FONTSIZE' } 	=> $tmp_font_size,
							$att_list->{ 'SPACING' } 	=> $tmp_spacing,
							$att_list->{ 'SUSCRIPT' } 	=> $tmp_su_script,
							$att_list->{ 'UNDERLINE' } 	=> $tmp_underline,
							$att_list->{ 'BOLD' }		=> $tmp_bold,
							$att_list->{ 'ITALIC' }		=> $tmp_italic	);

		# Get the inner line content
		$writer->raw( $node->xml_string() );
		$writer->endTag("run");
		$writer->end();

		# Fake run
		my $run = new Omni::Omnirun();
		
		# Set raw content
		$run->set_raw($output->value());

		# Update run list
		push @tmp_runs, $run;

		# Update content
		$tmp_content = $tmp_content . $run->get_content();
	}
	else
	{
		foreach my $rn (@all_runs)
		{
			my $run = new Omni::Omnirun();

			# Set raw content
			$run->set_raw($rn->sprint());

			# Update run list
			push @tmp_runs, $run;

			# Update content
			$tmp_content = $tmp_content . $run->get_content();
		}
	}
}

sub get_bullet
{
	my ($self) = @_;
	return $self->{ '_bullet' };
}

sub set_bullet
{
	my ($self, $bullet) = @_;
	$self->{ '_bullet' } = $bullet;		
}

sub get_runs_ref
{
	my ($self) = @_;
	return $self->{ '_runs' };
}

sub get_content
{
	my ($self) = @_;
	return $self->{ '_content' };
}

sub get_baseline
{
	my ($self) = @_;
	return $self->{ '_baseline' };
}

sub get_bottom_pos
{
	my ($self) = @_;
	return $self->{ '_bottom' };
}

sub get_top_pos
{
	my ($self) = @_;
	return $self->{ '_top' };
}

sub get_left_pos
{
	my ($self) = @_;
	return $self->{ '_left' };
}

sub get_right_pos
{
	my ($self) = @_;
	return $self->{ '_right' };
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
