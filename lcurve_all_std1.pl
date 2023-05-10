#! /usr/bin/perl
#make lightcurves of all of the files in subdirectories
#residing in PXXXX files and write them into a file


use warnings;
use strict;
use Data::Dumper;
use Getopt::Long;

my ($main_dir,@main_dir_list,$dir,@dir_list,$P_dir,@P_dir_list);
my (@data_dir,$file,@files,$mode,@file_list,@names,$i);
my (@layers,$collist,$side,$layer,$col,@names2,$k);

my $slew=0;#use this if slew data is to be analysed also
my $list="obsid_lc.list";
my $make_gif=1;

chomp($main_dir = `pwd`);


@main_dir_list=<*>;

foreach $dir (@main_dir_list){
  if($dir =~ /P\S+/){push @data_dir,$dir;}
}

foreach $P_dir (@data_dir){
  chdir $P_dir;
  @P_dir_list=<*>;

  if($slew){
    foreach $dir (@P_dir_list){
      if($dir =~ /(\S+-\S+-\S+-\S+)/){ 
	push @dir_list,"$P_dir/$dir/pca";
	push @names, $dir; 
     }
    }
  }
  else{
    foreach $dir (@P_dir_list){
      if($dir =~ /(\S+-\S+-\S+-\S+)/){
	if($dir !~ /[A|Z]$/){
	    #print "$dir\n";
	  push @dir_list,"$P_dir/$dir/pca";
	  push @names, $dir; 
	}
     }
    }
  }

chdir $main_dir;
}

$i=0;
foreach $dir (@dir_list){
    if(-e $dir){
      @files=`ls $dir/F*`;
      $k=1;
      foreach $file (@files){
	chomp($file);
	if($file =~ /\S+.bm.\S+/){}
	else{
	  if($file =~/\S.gz$/){
	    $mode=`ftlist ${file}[1] include=\"DATAMODE\" K`;
	    if($mode =~ /DATAMODE\=\s*'Standard1\S*\s*\//){
		print "$file\n";
	      push @file_list,$file;
	      push @names2,"$names[$i]_$k";
	      $k++;
	    }
	  }
	}
      }
  }	
$i++;
chdir $main_dir;
}

#@layers=(1,2,3);
#$collist="lcurve.col";
#  open(COLLIST, "> $collist");
#  foreach $layer (@layers) {foreach $side ("L","R") {
#	$col="X${layer}${side}SpecPcu2"; 
#	print COLLIST "$col\n";
#  }}
#  close(COLLIST);


$i=0;
foreach $file (@file_list){
print "saextrct infile=$file gtiorfile=APPLY gtiandfile='-' outroot=$file accumulate=one timecol=TIME columns=\"XeCntPcu0 XeCntPcu1 XeCntPcu2 XeCntPcu3 XeCntPcu4\" binsz=2 printmode=lightcurve lcmode=RATE spmode=SUM timemin=INDEF timemax=INDEF timeint=INDEF chmin=0 chmax=255 chint=INDEF chbin=INDEF\n";

system "saextrct infile=$file gtiorfile=APPLY gtiandfile='-' outroot=$file accumulate=one timecol=TIME columns=\"XeCntPcu0 XeCntPcu1 XeCntPcu2 XeCntPcu3 XeCntPcu4\" binsz=2 printmode=lightcurve lcmode=RATE spmode=SUM timemin=INDEF timemax=INDEF timeint=INDEF chmin=0 chmax=255 chint=INDEF chbin=INDEF";
#system "saextrct infile=$file gtiorfile=APPLY gtiandfile='-' outroot=$file.pcu2 accumulate=one timecol=TIME columns=XeCntPcu2 binsz=2 printmode=lightcurve lcmode=RATE spmode=SUM timemin=INDEF timemax=INDEF timeint=INDEF chmin=0 chmax=255 chint=INDEF chbin=INDEF";



print "fdump infile=${file}.lc+1 outfile=${file}.lc.dat columns='-' rows='-' prhead=no showcol=no showunit=no pagewidth=200 showrow=no clobber=yes\n";
system "fdump infile=${file}.lc+1 outfile=${file}.lc.dat columns='-' rows='-' prhead=no showcol=no showunit=no pagewidth=200 showrow=no clobber=yes";
  $i++;
}


if($make_gif){
$i=0;
foreach $file (@file_list){
  print("$file\n");
  open(LCPAR1, ">lcurve.par");
  print LCPAR1 "1\n$file.lc\n-\n2\n100000\n$file.flc\nyes\n$names2[$i].gif/GIF\nexit";
  system("lcurve <lcurve.par");
  $i++;
}
}
#Print to file
chdir $main_dir;
if(! open FILELIST, ">", "$list"){die "Cannot open $list for writing: $!";}

$i=0;
foreach $file (@file_list){
print FILELIST "${file}.lc.dat\n";
  $i++;
}
close(FILELIST);

