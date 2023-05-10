#! /usr/bin/perl

use warnings;
use strict;
use Data::Dumper;
use Getopt::Long;

my ($main_dir,@main_dir_list,$dir,@dir_list,$P_dir,@P_dir_list);
my (@data_dir,$file,@files,$mode,@file_list,@names,$i);
my (@layers,$collist,$side,$layer,$col,@names2,$k);

my $slew=1;#use this if slew data is to be analysed also

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
      if($dir =~ /(\S+-\S+-\S+-\d+)[A|Z]/){} 
      else{
	push @dir_list,"$P_dir/$dir/pca";
	push @names, $dir;
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
	$mode=`ftlist $file K`;
	if($mode =~ /DATAMODE\=\s*'Standard2\S*\s*\//){
	  push @file_list,$file;
	  push @names2,"$names[$i]_$k";
	  $k++;
	}
      }
  }	
$i++;
chdir $main_dir;
}

@layers=(1,2,3);
$collist="lcurve.col";
  open(COLLIST, "> $collist");
  foreach $layer (@layers) {foreach $side ("L","R") {
	$col="X${layer}${side}SpecPcu2"; 
	print COLLIST "$col\n";
  }}
  close(COLLIST);


$i=0;
foreach $file (@file_list){
system "saextrct infile=$file gtiorfile=APPLY gtiandfile='-' outroot=$file accumulate=one timecol=TIME columns=\@$collist binsz=16 printmode=lightcurve lcmode=RATE spmode=SUM timemin=INDEF timemax=INDEF timeint=INDEF chmin=0 chmax=255 chint=INDEF chbin=INDEF";
  $i++;
}


$i=0;
foreach $file (@file_list){

  print("$file\n");
  open(LCPAR1, ">lcurve.par");
  print LCPAR1 "1\n$file.lc\n-\n16\n1000\n$file.flc\nyes\n$names2[$i].gif/GIF\nexit";
  system("lcurve <lcurve.par");
  $i++;
}


