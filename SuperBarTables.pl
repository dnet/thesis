# Read in a tab-delimited file of data and produce
# a super-duper Latex booktabs table with a bar
# chart with errorbars in the right column.  You
# need a recent version of the "PGF" drawing package
# as well as the "booktabs" package.
#
# First line of data file is headings of table columns:
#    Mfg\tEngine\tCost\tPeak horsepower\t1 s.d.
# If multi-line headers are needed they can follow but
# must use the flag "HEAD" somewhere on the line (deleted).
#
# Then comes a control line with column contains the bar
# chart data and which has the error bar value (if any).
# This is done by putting a keyword in the same tab-
# delimited column as the heading and data.
# Keywords (seperate by commas)
#    val    - this column has the data value
#    sd     - column with errorbar value
#    del    - don't include this column in the output
#    dec    - column has decimal value, align the points    
#    decX   - column is decimal limit, to the Xth decimal place
#    int    - round column to nearest integer value
#    sdpm   - combine sd with value column using \pm notation
#
# After this should come the data in the same column
# order.  During the data, a line with starting with a "\"
# is just output as is (could be a \midrule command for example).
#
# Parameters:
#   $1 - tab-delimited control file with data
#   $2 - how wide (in cm) to make the bar chart in the right column
#   $3 - minimum value of the bar graph
#   $4 - maximum value of the bar graph
#   $5 - if "1", ommit the begin/end table and center tags
#   $6 - if given, add x-axis at label tics at locations specified 
#        by this comma-delimited field "6,7,8"
#
# If only tabular parameter is set, then no begin/end table or
# center tags are output.  This allows the output file to be
# included in another document with a caption, label, etc:
#   \begin{table}[t]
#     \begin{center}
#       \input{chapter6/init.tex}
#       \caption{My super table}
#     \end{center}
#   \end{table}
#
# Copyright 2007 by Keith Vertanen

use strict;

if ( @ARGV < 4 )
{
    print "$0 <file> <bar width cm> <min val> <max val> [only tabluar] [add scale]\n"; 
    exit(1);
}

# The amount of the vertical space to consume with the bar
my $BAR_VERTICAL = 0.75;

# How tall the bars are
my $BAR_HEIGHT   = 0.5;

# Height of the scale axis legend
my $SCALE_HEIGHT = 0.30;

# Total height of a scale tic mark 
my $SCALE_TIC_HEIGHT = 0.1;

# Padding adding to RHS when scale is being used, prevents last scale
# label from going out of the table width.
my $SCALE_RIGHT_PAD = 0.50;

# Push it up a bit to line up with text
my $VERTICAL_FUDGE = 0.09;

# How tall the error bars are
my $ERROR_BAR_HEIGHT = 0.075;

my $dataFile;
my $width;
my $minVal;
my $maxVal;
my $noTableTags = 0;
my $addScale = 0;
my @tics;
my $tic;
my $widthPlusPad;

($dataFile, $width, $minVal, $maxVal, $noTableTags, $addScale) = @ARGV;

# When there is a scale, add right padding
$widthPlusPad = $width;

if ($addScale)
{
	@tics = split(/,/, $addScale);
	$widthPlusPad += $SCALE_RIGHT_PAD;
}

my $ticX;
my $ticTop;
my $ticTextY;
my $line;
my @chunks;
my @headings;
my @headingLines;
my @delCol;
my @decCol;
my @decLimit;
my @intCol;
my $valCol;
my $sdCol;
my $i;
my $j;
my $lineNum = 0;
my $numCols;
my $output = 0;
my @dataLines;
my $pos;
my $barRight;
my $barTop;
my $barBottom;
my $val;
my $sd;
my $sdpm = 0;
my $errorLeft;
my $errorRight;
my $errorTop;
my $errorBottom;
my $errorMid;
my $offSides;
my $totalCols;
my $scaleCenter;

$barBottom   = ($BAR_HEIGHT * (1.0 - $BAR_VERTICAL)) / 2 + $VERTICAL_FUDGE;
$barTop      = $BAR_HEIGHT - $barBottom + $VERTICAL_FUDGE;
$barBottom   = sprintf "%0.3f", $barBottom;
$barTop      = sprintf "%0.3f", $barTop;

$errorMid    = ($barTop - $barBottom) / 2.0 + $barBottom;
$errorTop    = $errorMid + ($ERROR_BAR_HEIGHT / 2);
$errorBottom = $errorMid - ($ERROR_BAR_HEIGHT / 2);
$errorMid    = sprintf "%0.3f", $errorMid;
$errorTop    = sprintf "%0.3f", $errorTop;
$errorBottom = sprintf "%0.3f", $errorBottom;

my $inHeading = 1;
my $readKeyword = 0;

open(IN, $dataFile);
while($line = <IN>)
{
    $line =~ s/[\n\r]//g;

    if (($lineNum == 0) || (($inHeading) && ($line =~ /HEAD/)))
	{
		# First heading line
        if (@headings == 0)
        {
            #@headings = split(/[(\t)( ){2,}]/, $line);
			@headings = split(/\t/, $line);
        	$numCols = @headings;
        }
        # We may have multiple header lines
        $line =~ s/\s{0,}HEAD\t//g;
        push @headingLines, $line;
#print "HEAD: " . $headingLines[@headingLines - 1] . "\n";
	}
	elsif (!$readKeyword)
	{
		# Keyword line
        $inHeading = 0;
        $readKeyword = 1;
		@chunks = split(/\t/, $line);
        #@chunks = split(/[(\t)( ){2,}]/, $line);

		for ($i = 0; $i < @chunks; $i++)
		{
			if ($chunks[$i] =~ m/del/i)
			{
				$delCol[$i] = 1;
			}
			if ($chunks[$i] =~ m/val/i)
			{
				$valCol = $i;
			}
			if ($chunks[$i] =~ m/sd/i)
			{
				$sdCol = $i;
				if ($chunks[$i] =~ m/sdpm/i)
				{
					$sdpm = 1;
					$delCol[$i] = 1;
				}
			}
			if ($chunks[$i] =~ m/dec/i)
			{
				$decCol[$i] = 1;
				
				# See if it is a "decX" flag, assume one digit
				if ($chunks[$i] =~ m/dec(\d+)/)
				{
					$decLimit[$i] = $1;
				}
			}
			if ($chunks[$i] =~ m/int/i)
			{
				$intCol[$i] = 1;
			}
			
		}
#print "KEYWORD: $line \n";
	}
	else
	{
		push @dataLines, $line;
	}

	$lineNum++;
}
close(IN);

if (!$noTableTags)
{
	print "\\begin{table}\n";
	print " \\begin{center}\n";
}

# Use styles for all the drawing stuff, eash to change in one place then.
print "  \\tikzstyle barchart=[fill=black!20,draw=black]\n";
print "  \\tikzstyle errorbar=[very thin,draw=black!75]\n";
print "  \\tikzstyle scale=[very thin,draw=black!75]\n";

# Header line for the table
print "  \\begin{tabular}{ ";
for ($i = 0; $i < $numCols; $i++)
{
	if (!$delCol[$i])
	{
		if ($decCol[$i])
		{
			$totalCols += 2;
			print "r\@\{\.\}l ";
		}
		else
		{
			$totalCols += 1;
			print "l ";
		}
	}
}

# Extra column for the graph if a value column is specified
if ($valCol)
{
	$totalCols += 1;
	print "l ";
}

print "}\\toprule\n";

# Heading line(s)
for ($i = 0; $i < @headingLines; $i++)
{
    $output = 0;
    for ($j = 0; $j < $numCols; $j++)
    {
        @chunks = split(/\t/, $headingLines[$i]);
        #@chunks = split(/[(\t)( ){2,}]/, $headingLines[$i]);
    
        if (!$delCol[$j])
        {
            if ($output)
            {
                print "\&";
            }
    
            if ($decCol[$j])
            {
                print " \\multicolumn\{2\}\{l\}\{" . $chunks[$j] . "\} ";
                $output = 1;
            }
            else
            {
                print " " . $chunks[$j] . " ";
                $output = 1;
            }
        }
    }
    if ($valCol)    
    {   
        print "& ";
    }

    print "\\\\\n";    
}

print " \\midrule\n";

# Now put in the data
$i = 0;
while ($i < @dataLines)
{
	@chunks = split(/\t/, $dataLines[$i]);
    #@chunks = split(/[(\t)( ){2,}]/, $dataLines[$i]);

#	print $dataLines[$i] . "\n";

	if (index($dataLines[$i], "\\") == 0)
	{
		# Allow output of other things like "\addlinespace[8pt]" in the table
		print $dataLines[$i] . "\n";
	}	
	elsif (@chunks > 0)
	{
		$output = 0;
		$val = 0;
		$sd = 0;

		for ($j = 0; $j < @chunks; $j++)
		{
			# Remember the val and sd when we run across them
			if ($valCol == $j)
			{
				$val = $chunks[$j];
			}
			if ($sdCol == $j)
			{
				$sd = $chunks[$j];
			}
				
			if (!$delCol[$j])
			{
				if ($output)
				{
					print "\&";
				}

				#print "j = $j, sdCol = $sdCol \n";

				if ($decCol[$j])
				{
					if ($decLimit[$j] > 0)
					{
						$chunks[$j] = sprintf "%0." . $decLimit[$j] . "f", $chunks[$j];
					}

					# Spit the floating point number with a column delimiter
					$chunks[$j] =~ s/\./\&/;
					print " " . $chunks[$j] . " ";

					if (($valCol == $j) && ($sdpm))
					{
						if ($decLimit[$sdCol] > 0)
						{
							$chunks[$sdCol] = sprintf "%0." . $decLimit[$sdCol] . "f", $chunks[$sdCol];
						}
					
						print "\$\\pm\$ " . $chunks[$sdCol] . " ";
					}

					$output = 1;
				}
				else
				{
					# Round to nearest int
					if ($intCol[$j])
					{
						print " " . int($chunks[$j] + .5 * ($chunks[$j] <=> 0)) . " ";
					}
					else
					{
						print " ". $chunks[$j] . " ";
					}

					if (($valCol == $j) && ($sdpm))
					{
						print "\$\\pm\$ " . $chunks[$sdCol] . " ";
					}

					$output = 1;
				}


			}   
		}

		# Now for our super bar graph
		print "&\n";

		# Put in a minipage environment so we can vertically center
		print "  \\begin{minipage}[c]{" . $widthPlusPad . "cm}\n";
		print "   \\begin{tikzpicture}\n";

		# Force the desired size
		print "    \\draw (0cm,0cm) ($widthPlusPad,$BAR_HEIGHT);\n";

		$offSides = 0;

		# Draw the bar
		$barRight = ($val - $minVal + 0.0) / ($maxVal - $minVal + 0.0) * ($width + 0.0);
		if ($barRight > $width)
		{
			$barRight = $width;
			$offSides = 1;
		}
		elsif ($barRight < 0.0)
		{
			$barRight = 0.0;
			$offSides = 1;
		}

		$barRight  = sprintf "%0.3f", $barRight;

		print "    \\draw[barchart] (0,$barBottom) rectangle ($barRight,$barTop);\n";

		# Now for the error bars
		if (($sdCol) && (!$offSides))
		{
			$errorLeft = ($val - $sd - $minVal + 0.0) / ($maxVal - $minVal + 0.0) * ($width + 0.0);

			$errorRight = ($val + $sd - $minVal + 0.0) / ($maxVal - $minVal + 0.0) * ($width + 0.0);

			$errorLeft  = sprintf "%0.3f", $errorLeft;
			$errorRight = sprintf "%0.3f", $errorRight;

			print "    \\draw[errorbar] ($errorLeft,$errorMid) -- ($errorRight,$errorMid);\n";
			print "    \\draw[errorbar] ($errorLeft,$errorTop) -- ($errorLeft,$errorBottom);\n";
			print "    \\draw[errorbar] ($errorRight,$errorTop) -- ($errorRight,$errorBottom);\n";

			if ($addScale)
			{
				# Adding an axis with text causes a shift in the coordinate system to the right
				# for some reason.  So we'll put a blank text node in every bar chart area as
				# well so things will line up with the axis.
				print "    \\draw[scale] (0,0) node[] {};\n";	
			}
			
		}

		print "   \\end{tikzpicture}\n";
		print "  \\end{minipage} ";

		print "\\\\\n";
	}
	$i++;
}

if ($addScale)
{
	# Extra row for the bar chart scale
	
	# Nothing in any column except for the last one
	print " \\multicolumn\{" . ($totalCols - 1) . "\}\{l\}\{\} &";


	# Put in a minipage environment so we can vertically center
	print "  \\begin{minipage}[c]{" . $widthPlusPad  . "cm}\n";
	print "   \\begin{tikzpicture}\n";

	# Force the desired size
	print "    \\draw (0cm,0cm) (" . $widthPlusPad . ",$SCALE_HEIGHT);\n";

	# The axis is far enough down so the tic marks go up to the very top
	$scaleCenter = $SCALE_HEIGHT - $SCALE_TIC_HEIGHT;
	$ticTop = $scaleCenter + $SCALE_TIC_HEIGHT;
	
	# Where to center the tic text 
	$ticTextY = -0.1;
	
	# Draw the line
	$barRight = sprintf "%0.3f", $width;
	print "    \\draw[scale] (0,$scaleCenter) -- ($barRight,$scaleCenter);\n";

	# Add the tic lines, above the axis line
	foreach $tic (@tics)
	{
		if (($tic >= $minVal) && ($tic <= $maxVal))
		{
			$ticX = ($tic - $minVal + 0.0) / ($maxVal - $minVal + 0.0) * ($width + 0.0);
			print "    \\draw[scale] ($ticX,$scaleCenter) -- ($ticX,$ticTop);\n";	
			print "    \\draw[scale] ($ticX,$ticTextY) node[text width=0pt, text height=0pt, font=\\footnotesize] {$tic};\n";	

		}
	}

	print "   \\end{tikzpicture}\n";
	print "  \\end{minipage} ";
	
	print "\\\\\n";
}

print "  \\bottomrule\n";
print "  \\end{tabular}\n";

if (!$noTableTags)
{
	print " \\end{center}\n";
	print "\\end{table}\n";
}

