#!/usr/bin/perl
#
#
# Create gnuplot plots from verobs .txt files
#
# Usage: verobs2gnuplot.pl *.txt, where *.txt is the textfiles produced by verobs
#

push @INC, "$ENV{SCR}";
eval { push @INC, "$ENV{LOCAL_DEFS_PATH}"; } ;
require maindefs ;
eval { require local_defs ; } ;

my $searchdir = "";
my $vertype = "SURF";
my $cleantxt = 0 ;
my $debug = $ENV{MONITOR_DEBUG} or $debug = 0 ;

# Set colors for lines

@col_def_lt  = (0,1,2,3,4,5,6,8,7,9);

require $ENV{LOCALDEFS} if $ENV{LOCALDEFS} ;
$xticmax = $xticmax or $xticmax=72 ;
$xticinc = $xticinc or $xticinc= 3 ;

# Line thickness
$lw=2;

# Check output type end extension

$OUTPUT_TYPE = $ENV{OUTPUT_TYPE} or $OUTPUT_TYPE = 2 ;

# PS/PNG/JPG/SVG as output and their color definitions for map and scatter
$maxcol = 11 ;
if ( $OUTPUT_TYPE eq 1 ) {
    $terminal    = "set terminal postscript landscape enhanced colour";
    @map_colors  = ("7","3","5","6","8","4");
    @scat_colors = ("3","5","2","6","8","1","4","9","7","10","11","12");
    $map_pt=7;
} elsif ( $OUTPUT_TYPE eq 2 ) {
    $terminal    = "set terminal png";
    @map_colors  = ("-1","8","5","7","1","13");
    @scat_colors = ("8","5","15","14","2","7","9","1","13","0","18","8","-1");
    $map_pt=13;
} elsif ( $OUTPUT_TYPE eq 3 ) {
    $terminal    = "set terminal jpeg";
    @map_colors  = ("-1","8","5","7","1","13");
    @scat_colors = ("8","5","15","14","2","7","9","1","13","0","18","8","-1");
    $map_pt=13;
} elsif ( $OUTPUT_TYPE eq 4 ) {
    $terminal    = "set terminal svg enhanced fsize 8 ";
    @map_colors  = ("7","3","5","6","8","4");
    @scat_colors = ("3","5","2","6","8","1","4","9","7","10","11","12");
    $map_pt=7;
} else {
    die "Unknown OUTPUT_TYPE $OUTPUT_TYPE\n";
} ;
    
@EXT = ('','.ps','.1.png','.1.jpg','.svg') ;

# Read arguments

while ( <@ARGV> ) {
   if ( /-d/) { $searchdir = $ARGV[$n+1] or die "Please use -d SEARCHDIR \n"; } ;
   if ( /-t/) { $vertype   = $ARGV[$n+1] or die "Please use -t VERTYPE   \n"; } ;
   if ( /-c/) { $cleantxt  = 1 ; } ;
   $n++ ;
}


if ( $searchdir ne "" ) {

 print" Scanning $searchdir for *.txt files \n";

 # Read file from the current directory
 opendir MYDIR, "$searchdir" ;
 @FILES = grep !/^\.\.?/, readdir MYDIR ;
 @FILES = grep /\.txt$/, @FILES ;
 close MYDIR ;

} else { @FILES = grep(!/\-t|\b$vertype\b/,@ARGV) ; } ;

if ( $vertype eq "SURF" ) {
 $map_ps=1;
} elsif ( $vertype eq "TEMP" ) {
 $map_ps=2;
} else {
 die "Unknown vertype:$vertype\n"; 
};

SCAN_INPUT: foreach $input_file (@FILES) {

    print "Process:$input_file \n" if ( $debug > 0 ) ;

    @col_def   = ();
    @heading   = ();
    @sfile     = ();
    @sint      = ();
    @sintu     = ();

    $col_count = -1 ;

    if ( defined $minnum ) {
       undef $minnum ;
       undef $maxnum ;
       undef $ticnum ;
    } ;

    # Examine file name

    @tmp    = split( '_', $input_file );
    $partag = $tmp[-2];
    $prefix = shift(@tmp);
    @tmp    = split( '.txt', $input_file );

    $output_file = shift(@tmp) . $EXT[$OUTPUT_TYPE] ;
    open FILE, "< $input_file";

    # Parameter dependent settings
    # Set log scale for various parameters
    $xscale  = "";
    @logscales =('PE','PE12','PE1','PE3','PE6','CH','VI') ;
    $xscale="set logscale x" if grep /\b$partag\b/, @logscales ;

    # Set lager scatter point size for cloud cover
    $ps_scat = 1 ;
    if ( $partag eq "NN" ) { $ps_scat=2 ; } ;

    SCAN_FILE: while (<FILE>) {

        #  
        # Scan through the file and extract the necessary information
        # Add an extra backslash to avoid subscripts in experiment names
        #  

        chomp;

        if ( $_ =~ /#END/    ) { last SCAN_FILE; }
        if ( $_ =~ /#NEXP/   ) { $nexp = substr( $_, 5 ); next SCAN_FILE; }
        if ( $_ =~ /#XMIN/   ) { @tmp = split (' ',$_ ) ; $xmin   = $tmp[1]; next SCAN_FILE; }
        if ( $_ =~ /#XMAX/   ) { @tmp = split (' ',$_ ) ; $xmax   = $tmp[1]; next SCAN_FILE; }
        if ( $_ =~ /#YMIN/   ) { @tmp = split (' ',$_ ) ; $ymin   = $tmp[1]; next SCAN_FILE; }
        if ( $_ =~ /#YMAX/   ) { @tmp = split (' ',$_ ) ; $ymax   = $tmp[1]; next SCAN_FILE; }
        if ( $_ =~ /#EXPNAMES/ ) { @expnames = split (' ',$_ ) ; shift @expnames ;}

        if ( $_ =~ /#HEADING/ ) {
            $heading = substr( $_, 11 );
            if ( $OUTPUT_TYPE eq 1 ) { $heading =~ s/_/ /g; } ;
            @heading = (@heading,$heading);
            next SCAN_FILE;
        }
        if ( $_ =~ /#SELECTION/ ) {
            $selection = substr( $_, 11 ); 
            if ( $OUTPUT_TYPE eq 1 ) { $selection =~ s/_/ /g; } ;
            next SCAN_FILE;
        }
        if ( $_ =~ /#YLABEL/ ) {
            $ylabel = substr( $_, 8 );
            if ( $OUTPUT_TYPE eq 1 ) { $ylabel =~ s/_/ /g; } ;
            next SCAN_FILE;
        }
        if ( $_ =~ /#XLABEL/ ) {
            $xlabel = substr( $_, 8 );
            if ( $OUTPUT_TYPE eq 1 ) { $xlabel =~ s/_/ /g; } ;
            next SCAN_FILE;
        }
        if ( $_ =~ /#MINNUM/ ) {
            $minnum = substr( $_, 10 );
            $minnum =~ s/^\s+//;
            $minnum =~ s/\s+$//;
            next SCAN_FILE;
        }
        if ( $_ =~ /#MAXNUM/ ) {
            $maxnum = substr( $_, 10 );
            $maxnum =~ s/^\s+//;
            $maxnum =~ s/\s+$//;
            next SCAN_FILE;
        }
        if ( $_ =~ /#TICNUM/ ) {
            $ticnum = substr( $_, 10 );
            $ticnum =~ s/^\s+//;
            $ticnum =~ s/\s+$//;
            next SCAN_FILE;
        }
        if ( $_ =~ /#MISSING/ ) {
            $missing = substr( $_, 10 );
            $missing =~ s/^\s+//;
            $missing =~ s/\s+$//;
            next SCAN_FILE;
        }

        if ( $_ =~ /#COLUMN/ ) {
            $col_count++ ;
            unless ( exists($col_def_lt[$col_count]) ) {
                $col_def_lt[$col_count]=$col_count ;
            } ;


            $legend = substr( $_, 11 ) ;
            if ( $OUTPUT_TYPE eq 1 ) { $legend =~ s/_/\\_/g; } ;

            @col_def = (@col_def,
                       { LEGEND => $legend ,
                         COLUMN => substr( $_, 8, 3 ),
                         PT     => 7,
                         LT     => $col_def_lt[$col_count],
                        },
            ) ;
            next SCAN_FILE;
        }

        if ( $_ =~ /#SLEVEL/ ) {
            @tmp = split( ' ', $_ );
            @sfile = ( @sfile, $tmp[1] );
            @sint  = ( @sint,  $tmp[2] );
            @sintu = ( @sintu, $tmp[3] );
            next SCAN_FILE;
        }
    }

    close FILE;

    #
    # Set plot colors and symbols depending on type of plot
    #

    my $ii = scalar (@col_def);
    unless ( $ii eq 0 ) {
       $ncol = 0;
       if ( $col_def[$ii-2]{LEGEND} ne OBS ) { $ncol = ( $ii -1 ) / $nexp ; } ;
     
       for (my $i=0; $i < $ii; $i++) {
          if ( $col_def[$i]{LEGEND} =~/MAE/  ) {  $col_def[$i]{PT} = 8 } ;
          if ( $col_def[$i]{LEGEND} =~/RMSE/ ) {  $col_def[$i]{PT} = 7 } ;
          if ( $col_def[$i]{LEGEND} =~/BIAS/ ) {  $col_def[$i]{PT} = 4 } ;
          if ( $col_def[$i]{LEGEND} =~/STDV/ ) {  $col_def[$i]{PT} = 3 } ;
          if ( $col_def[$i]{LEGEND} =~/VAR/  ) {  $col_def[$i]{PT} = 3 } ;
          if ( $col_def[$i]{LEGEND} =~/SKW/  ) {  $col_def[$i]{PT} = 3 } ;
   
          if ( $nexp ne 0 ) { $col_def[$i]{LT} = $col_def_lt[1 + $i % $nexp] ; } ;
   
         if ( $col_def[$i]{LEGEND} eq 'CASES' ) {  $col_def[$i]{LT} = 0 } ;
   
       } ;
    } ;


    #
    # Start writing the plotting file
    #

    # Print the header
    &header;

    # File type dependent options

    PLOT_TYPES: {

        if ( $prefix =~ /^($plot_prefix[12]|$plot_prefix[13])\b/ ) {
            &plot_sign;
            last PLOT_TYPES;
        }
        if ( $prefix =~ /^($plot_prefix[2]|$plot_prefix[3])\b/ ) {
            &timeserie;
            last PLOT_TYPES;
        }
        if ( $prefix =~ /^($plot_prefix[0]|$plot_prefix[1]|$plot_prefix[11])\b/ ) {
            &gen_stat;
            last PLOT_TYPES;
        }
        if ( $prefix =~ /^($plot_prefix[4]|$plot_prefix[5])\b/ ) {
            &plot_vert;
            last PLOT_TYPES;
        }
        if ( $prefix =~ /^$plot_prefix[8]\b/ ) {
            &plot_freq;
            last PLOT_TYPES;
        }
        if ( $prefix =~ /^($plot_prefix[9]|$plot_prefix[10])\b/ ) {
            $xrange="[$xmin:$xmax]";
            $yrange="[$ymin:$ymax]";
            &plot_scat;
            last PLOT_TYPES;
        }
        if ( $prefix =~ /^($plot_prefix[6]|$plot_prefix[7])\b/ ) {
            &plot_map;
            last PLOT_TYPES;
        }

        print "Skip unknown file : $input_file \n";
        close GP;
        next SCAN_INPUT;

    }

    # Call gnuplot

    print GP "$plot";
    close GP;
    system("gnuplot plot.gp");
    system("rm -f ${input_file}*") if ( $cleantxt == 1 ) ; 

    print "Created:$output_file \n" if ( $debug > 0 ) ;

}
#################################################################
#################################################################
#################################################################
sub plot_sign {

 $sign_test_joint = $ENV{SIGN_TEST_JOINT} or $sign_test_joint = 'F';
print GP <<EOF;
set xtics 0,$xticinc,$xticmax
EOF
  
  if ( defined $minnum ) {
    print GP <<EOF;
set y2range [$minnum:$maxnum]
set y2label "No cases"
set y2tics $minnum,$ticnum,$maxnum
EOF
  } else {
    print GP <<EOF;
set y2range [0:]
set y2label "No cases"
set y2tics 0,1000
EOF
  } ;

 if ( $sign_test_joint eq 'T' ) {
  $plot = "plot " ;
  $i = 0;
  foreach $exp (@expnames) {
 
   $file = 'sub_'.$input_file.'_'.$exp ;
   $i++;

   $plot = $plot . "'$file' using 1:2:3 title '$exp' with errorbars lt $col_def_lt[$i] lw $lw, ";
   $plot = $plot . "'$file' using 1:2 notitle  with lines lt $col_def_lt[$i] lw $lw, ";

  }
  $plot = $plot . "'${file}' using 1:4 axes x1y2 title 'Cases' with linespoints lt 0 lw $lw ";

 } else {
  $plot = "plot '$input_file' notitle with errorbars lw $lw, ";
  $plot = $plot . "'$input_file' using 1:2 notitle with linespoints lw $lw, ";
  $plot = $plot . "'${input_file}n' using 1:2 axes x1y2 title 'Cases' with linespoints lt 0 lw $lw ";
 }

}
#################################################################
#################################################################
#################################################################
#################################################################
#################################################################
#################################################################
sub plot_command {

    $plot = "plot ";

    $i = -1;
    foreach (@col_def) {
        $i++;
        if ( $i gt 0 ) { $plot = "$plot,"; }
        $column = 1 * $col_def[$i]{COLUMN} ;
        $plot = $plot . " '$input_file' using 1:" . $column ;
        if ( $col_def[$i]{LEGEND} =~ /CASES/ ) {
          $plot = $plot . " axes x1y2 title '$col_def[$i]{LEGEND}' with linespoints lt 0 lw $lw ";
        } else {
          $plot = $plot . " title '$col_def[$i]{LEGEND}' with linespoints lt $col_def[$i]{LT} lw $lw pt $col_def[$i]{PT}";
	}
    }

}
#################################################################
#################################################################
#################################################################
sub header {

    # Create header
    $len_head = scalar(@heading) ;
    $heading =$heading[0];
    for ($i=1;$i<$len_head;$i++ ) { $heading=$heading."\\n $heading[$i]"; } ;

    open GP, ">plot.gp";

    print GP <<EOF;
$terminal
$font
set output '$output_file'
set datafile missing "$missing"
set title "$heading"

set xlabel "$xlabel"
set ylabel "$ylabel"
set timefmt "%Y%m%d %H"
set grid
EOF
}
#################################################################
#################################################################
#################################################################
sub timeserie {

  if ( defined $minnum ) {
    print GP <<EOF;
set y2range [$minnum:$maxnum]
set y2label "No cases"
set y2tics $minnum,$ticnum,$maxnum
EOF
  } else {
    print GP <<EOF;
set y2range [0:]
set y2label "No cases"
set y2tics 0,1000
EOF
  } ;

    print GP <<EOF;
set xdata time
set format x "%d/%m\\n %HZ"
EOF

    &plot_command ;

}
#################################################################
#################################################################
#################################################################
sub gen_stat {

print GP <<EOF;
set xtics 0,$xticinc,$xticmax
EOF

  if ( defined $minnum ) {
    print GP <<EOF;
set y2range [$minnum:$maxnum]
set y2label "No cases"
set y2tics $minnum,$ticnum,$maxnum
EOF
  } else {
    print GP <<EOF;
set y2range [0:]
set y2label "No cases"
set y2tics 0,1000
EOF

    } ;

    &plot_command ;

}
#################################################################
#################################################################
#################################################################
sub plot_vert {

  if ( defined $minnum ) {
    print GP <<EOF;
set yrange [1000:10]
set x2range [$minnum:$maxnum]
set x2label "No cases"
set x2tics $minnum,$ticnum,$maxnum
EOF
  } else {
    print GP <<EOF;
set yrange [10:1000] reverse
set x2range [0:]
set x2label "No cases"
#set x2tics 0,300
EOF
  } ;
    $plot = "plot ";

    $i = -1;
    foreach (@col_def) {
        $i++;
        if ( $i gt 0 ) { $plot = "$plot,"; }
		$column = 1 * $col_def[$i]{COLUMN} ;
        $plot = $plot . " '$input_file' using " . $column . ":1";
        if ( $col_def[$i]{LEGEND} =~ /CASES/ ) {
          $plot = $plot . " title '$col_def[$i]{LEGEND}' with linespoints lt 0 lw $lw axis x2y1 ";
        } else {
          $plot = $plot . " title '$col_def[$i]{LEGEND}' with linespoints lt $col_def[$i]{LT} lw $lw pt $col_def[$i]{PT}";
	}
    }

}
#################################################################
#################################################################
#################################################################
sub plot_freq {
    print GP "$xscale \n";
    &plot_command ;
EOF
}
#################################################################
#################################################################
#################################################################
sub plot_scat {
  
print GP <<EOF;
set key outside 
EOF
    $plot = "plot $xrange$yrange";

    $i = -1;
    foreach (@sfile) {
        $i++;
        if ( $i gt 0 ) { $plot = "$plot,"; }
        if ( $i <= $maxcol ) { $color_id = $i; } else { $color_id = $maxcol; } ;
        if ( $sint[$i] eq "ALL" ) { 
          $plot = $plot . " '$input_file"."_".$_."' title '' lt -1 ps $ps_scat pt $map_pt";
        } else {
          $plot = $plot . " '$input_file"."_".$_."' title '$sint[$i]' lt $scat_colors[$color_id] ps $ps_scat pt $map_pt";
        };
    }

    if ( $prefix =~ /^($plot_prefix[9]|$plot_prefix[10])\b/ ) {
       $plot = $plot . ", x notitle with lines lt -1"; 
    }

}
#################################################################
#################################################################
#################################################################
sub plot_map {
  
print GP <<EOF;
set key outside 
EOF
    $plot = "plot ".$selection." 'coast.dat' notit with lines lt -1,";
    $i = -1;
    foreach (@sfile) {
        $i++;
        if ( $i gt 0 ) { $plot = "$plot,"; }
        $plot = $plot . " '$input_file"."_".$_."' title '$sint[$i] $sintu[$i]' lt $map_colors[$i] ps $map_ps pt $map_pt";
    }
}
