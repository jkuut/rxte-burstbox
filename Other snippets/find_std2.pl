#! /usr/bin/perl

use warnings;
use strict;
use Data::Dumper;
use Getopt::Long;

my ($main_dir,@main_dir_list,$dir,@dir_list,$P_dir,@P_dir_list);
my (@data_dir,$file,@files,$mode,@file_list,@names,$i);
my (@layers,$collist,$side,$layer,$col,@names2,$k);
my $outputfile="std2_list.txt";
my @file_list2;
my ($std1c,$std2c);
my @cc_list;

my $slew=0;

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
      if($dir =~ /(\S+-\S+-\S+-\d{2})[A|Z]/){} 
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
    $std2c=0;
    $std1c=0;

    if(-e $dir){
      @files=`ls $dir/F*`;
      $k=1;
     foreach $file (@files){
     if($file !~ /\S+.bm/){
	  chomp($file);
	  $mode=`ftlist $file K`;
	  if($mode =~ /DATAMODE\=\s*'Standard2\S*\s*\//){
	    if($std2c eq 0){
	    push @file_list,$file;
	    #$std2c++;
	    }
	  }
	  if($mode =~ /DATAMODE\=\s*'Standard1\S*\s*\//){
	    if($std1c eq 0){
	    push @file_list2,$file;
	    #$std1c++;
	    }
	  }
     }
     }
      if($std2c==1 && $std1c==0){push @file_list2," ";}
      if($std2c==0 && $std1c==1){push @file_list," ";}

      #push @cc_list,$std1c+$std2c;
    }	
$i++;
chdir $main_dir;
}

  if ( ! open WINPUT, ">", "$outputfile") {
	die "Cannot open'$outputfile for writing the input file: $!";
  }

  print "Writing an input file to: $outputfile\n";


$i=0;
foreach $file (@file_list){
    #if($cc_list[$i]==2){
print WINPUT "$file $file_list2[$i]\n";
#}
  $i++;
}


