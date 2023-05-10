#!/usr/bin/perl -w
#Perl script for merging pha files and marking low count rate channels as bad 
use strict;
use Getopt::Long;

my ($dir, $inputfile, $outdir); #system variables
my @dir_output;
my ($line, $i, $ii, $j, $s, $q, $lg_time);
my ($obsid, $fstatistic, $col_sum, $counts, $mean, $pha_num, $mean2, $peakcount, $bin_count, $iteration, $temp);	
my ($exposure, $fkeyprint, $t_count, $peak_i, $clip);
my (@data, @pha_files, @count_sum, @count_sum2, @exposures, @sum_pha_files, @number_of_pcus, @pcu_nums, @temp, @initial_pha_files);	#arrays
my ($command,$count,$exposure_t);
my $GXmode=0;

my $last_bin2="false";
my $burst_top="false";
my $list=0;
my $bkg_problem_flag=1; #set this to 1 if xspec is having problems with bkg <0s

my $doburst_rise=1;#Doing burst rise with better resolution (Use this almost always)

my $s_binsize=1; #use s_binsize=1 i.e. 0.25s resolution

my $dynamic_rsp=0;

GetOptions(
"dir=s" => \$dir,
"inputfile=s" => \$inputfile, 
"outdir=s" => \$outdir,
"list=s" => \$list
);

#script usage "help"
if(! defined($dir) && ! defined($inputfile)){die "Give input directory in format -dir XXX -outdir YYY or inputfile in format -inputfile ZZZ -outdir YYY\n";};
if(defined($dir) && defined($inputfile)){die "Give only one source: dir OR inputfile\n";};
if(! defined($outdir)){die "Give output directory in -outdir YYY\n";};


#Making sure the outdir exists, if not then creating one
unless(-e $outdir){
  mkdir $outdir, 0755 or die "can't make ${outdir} folder. Create such folder for output!\n";
}



#Reading all pha files from given dir if it is given and using the output as an $inputfile
if(defined($dir)){
	unless(-e $dir){die "Given dir ($dir) does not exists. Check that dir is given without \"/\" f.e. proc01 ";}
	@dir_output= `ls $dir | grep .pha`; 
	if( ! open DIR_OUTPUT, ">", "$outdir/pha_files.dbg"){die "Can not open $outdir/pha_files.dbg for writing";}
	foreach(@dir_output){print DIR_OUTPUT "$dir/$_";}
	close DIR_OUTPUT;
	$inputfile="$outdir/pha_files.dbg";
}


#Making sure the file exists
unless(-e $inputfile){
  die "Input file $inputfile does not exist!\n";
}


#Reading inputfile into array
if( ! open INPUT, "<", $inputfile) {
	die "Cannot open Input file $inputfile for reading: $!";
}

while(defined($line = <INPUT>)){
#	chomp($line);
	push @data, $line;
}

#Reading pcu_list.txt, which contains a list of pha-files and pcus on during each pha-file
#and pushing pha-files into an array @initial_pha_files and the number of pcus on into @number_of_pcus
#if the number of pcus on changes, then $dynamic_rsp=1
if( ! open PCUINPUT, "<", "$dir/pcu_list.txt") {
	die "Cannot open pcuinput file for reading: $!";
}
$i=0;
while(defined($line = <PCUINPUT>)){
#	chomp($line);
    if($line =~ m/\S+\/\S+\/(\S+.pha)\s\S+\s\S+\s(\S+)/){
        push @initial_pha_files, $1;
        @temp = split(/,/,$2);
        push @number_of_pcus, scalar(@temp);
        if($i == 0){ $temp = $2; }
        else{ 
            if($2 ne $temp ) { $dynamic_rsp=1; }       
        }
        $i++;
    }
}

if($dynamic_rsp){print "Using dynamic response mode!\n";}



#Getting the biggest time in the given data group
$lg_time=0;
foreach(@data){
	if($_ =~ m/[\S]+\_[0]?[0]?([\d]+).pha/){
		if($1 > $lg_time){$lg_time = $1;}
		}
}


#Arranging and filttering the pha files according to time.			
#(This part is not needed if the pha_files does have all the pha files in order)
$i=0;
while($i < $lg_time+1) {
    foreach(@data){		
	if($_ =~ m/([\S]+\_[0]?[0]?${i})\.pha/){
	    push @pha_files, $1;
	    
	    #Making sure that number of pcus are in order
	    $ii = 0;
	    foreach(@initial_pha_files){
		if($_ =~ m/[\S]+\_[0]?[0]?(\d+)\.pha/){
		    if($1 == $i){last}
		    $ii++;
		}
	    }
	    if($ii == 0 && $i != 0){die "No matching pha file found in pcu_list.txt for $i\n";}
	    push @pcu_nums, $number_of_pcus[$ii];
	}
    }
    $i++;
}

#Print pha files and corresponding number of pcus
#$i = 0;
#foreach(@pha_files){
#    print "$pha_files[$i] $pcu_nums[$i]\n";
#    $i++;
#}
#die;

#Getting obs_id for naming
if($pha_files[0] =~ /\S+\/(\S+)\_/){$obsid=$1;}


#New way that uses cnts per second
#Reading counts into array and getting the peak count
$i=0;
$peakcount=0;


#copying respfile
#if($pha_files[0] =~ /(\S+\/\S+\_\S+)\_\S+/){system "cp ${1}_cb.rsp ${outdir}/${obsid}_cb.rsp";}
if($pha_files[0] =~ /(\S+\/\S+\_\S+)\_\S+/){system "cp ${1}_*.rsp ${outdir}/";}
if($pha_files[0] =~ /(\S+\/\S+\_\S+)\_\S+/){system "cp ${1}_bkg_16s_64ch.pha ${outdir}/${obsid}_bkg_16s_64ch.pha";}
else {die "No response/bkg file found"}

#Chekking if resolution is 0.25s or 2s
$fkeyprint = `ftlist $pha_files[$i].pha+2 K include="ONTIME"`;
print "$fkeyprint\n";
if($fkeyprint =~ /ONTIME\s*=\s*2.000\S*/){
    #ONTIME  = 2.000000000000000E+00 / time on source
	$GXmode=1;
	print "GoodXenon 2s mode detected\n";
}


$i=0;
while($i < @pha_files){

	$fkeyprint = `ftlist $pha_files[$i].pha+1 K`;

	if($fkeyprint =~ /EXPOSURE=\s+\S+\s*\S\s*Uncorrected value was (\S+)/){
#	  $exposure=$1+0;
	    push @exposures, $1;
	    $exposure_t=$1;
	}
	else {
	    print "Can't get the exposure for $pha_files[$i].pha using uncorrected value\n";
	    if($fkeyprint =~ /EXPOSURE=\s+(\S+)\s*\S\s/){
	        push @exposures, $1;
	        $exposure_t=$1;
	    }
	}

	print "Exposure=$exposure_t\n";

	if($exposure_t gt 0.05){

	    if($bkg_problem_flag){
	        system "fparkey fitsfile=$pha_files[$i].pha value='${outdir}/${obsid}_bkg_16s_64ch.pha' keyword='BACKFILE'";
	        print "fparkey fitsfile=$pha_files[$i].pha value='${outdir}/${obsid}_bkg_16s_64ch.pha' keyword='BACKFILE'\n";
	        #system "fparkey fitsfile=$std2pha value='${rootbkg}_std2.pha' keyword='BACKFILE'";
	    }

	    if(! open XSINPUT, ">", "${outdir}/pha_${i}_commands.xcm") {
		    die "Cannot open ${outdir}/pha_${i}_commands.xcm for output: $!";}
	    
	    #if output to file then Xspec logfile is created
	    print XSINPUT "log ${outdir}/pha_${i}_out.log \n";
	    print XSINPUT "data $pha_files[$i]\n";
	    print XSINPUT "backgrnd ${outdir}/${obsid}_bkg_16s_64ch.pha\n";
	    print XSINPUT "ignore **-2. 60.-**\n";
	    print XSINPUT "show data\n";
      	print XSINPUT "exit\n";	
	    close(XSINPUT);

	    $command="xspec - ${outdir}/pha_${i}_commands.xcm";
	    print "$command\n";
	    system($command);

        if(! open XSLOG, "<", "${outdir}/pha_${i}_out.log") {
	        die "Cannot open log ${outdir}/pha_${i}_out.log for reading: $!";
        }

        $count=0;
        while(<XSLOG>){	#Reading each line of log
	        if(/#Net count rate \(cts\/s\) for Spectrum:1\s+(\S+)\s*\+\/\-\s*(\S+)\s\S+/){
	         $count=$1;
	        }
        }
        close XSLOG;
    }else{
        $count=0;
    }


    push @count_sum2, $count;
    if($count>$peakcount){
    $peakcount=$count;
    $peak_i=$i;
    }


  $i++;
}


#Getting the sum of column counts and adding pha's together if count rate not high enough
$i=0;
$pha_num=0;

while($i < @pha_files){
    if($exposures[$i] ne 0){

        if($i<=$peak_i){
	        $i=sumphas($pha_files[$i], $i, $pha_num, $outdir, 1, $dynamic_rsp, @pcu_nums);
	        $pha_num++;
        }
        elsif($i>$peak_i){
	        $j=1;
	        $iteration= "False";
	        while($iteration eq "False"){

	            $col_sum=0;

	            if($#pha_files >= (2**($j-1)+$i)){
	                for($q=$i; $q<(2**($j-1)+$i); $q++){
	                    $col_sum+=$count_sum2[$q];
	                }
	            } else {
	                for($q=$i; $q<($#pha_files); $q++){
	                    $col_sum+=$count_sum2[$q];
	                }
	                $last_bin2 = "True";
	            }

	            $bin_count=(0.707**$j)*$peakcount;
	            if(($col_sum >= $bin_count) || ($last_bin2 eq "True")){
			        $iteration = "True";
			        $i=sumphas($pha_files[$i], $i, $pha_num, $outdir, $j, $dynamic_rsp, @pcu_nums);
			        $pha_num++;
	            } else{ $j++; }
	        }   
        }   
    } else{ $i++; }
}


print "\nDone adding bins\n";

#Calculating and printing statistics of bins
$mean=0;
foreach(@count_sum2){$mean=$mean+$_;}
$mean2 = $mean/$pha_num;


print "\n\n******************************************************\n";
print "There are total of $mean counts and $pha_num merged pha files\n";
print "Avarage count value of bin is: $mean2\n";
print "******************************************************\n\n";


#Printing a list of pha files into file if $list defined
if($list){
    if(! open FILELIST, ">", "$list"){die "Cannot open $list for writing: $!";}		
    foreach(@sum_pha_files){
        # $sum_pha_file=$_;
        print FILELIST "${_}.pha\n";
    }
    close(FILELIST);
}

print "\n\nFINISHED\n";


############################################################################
############################################################################
sub sumphas
{

my ($pha_file,$i,$pha_num,$outdir,$j, $dynamic_rsp, @pcu_nums) = @_;
my $sumpha;
my ($time, $k, $q, $num);
my ($bin, $ini_size, $real_bin, $virtual_bin);
my $new_bincount;
my ($filelist, $bkgfilelist);
my $last_bin="false";


#Making $j values correspond actual bin sizes in seconds			

$time=$s_binsize*0.25*2**($j-1);
if($GXmode){$time=$s_binsize*2.0*2**($j-1);}

#Changing numbering into 001
if($pha_num < 10){$pha_num="00${pha_num}"}
elsif($pha_num >= 10 && $pha_num <100){$pha_num="0${pha_num}"}

$sumpha="${outdir}/${obsid}_${pha_num}";


$filelist="";
$bkgfilelist="";

$ini_size=0.25; #Parameter for smallest bin size (Important!)
if($GXmode){$ini_size=2.0;}

#Making the last bin a sum of what is left
if((@pha_files-$i)*$ini_size < $time){
    $time=(@pha_files-$i)*$ini_size;
    $last_bin="true";
}

#Make hard upperlimit of 16s for a bin time
if($time > 16.0){$time=16.0}


print "\nSumpha is going to be $sumpha $time s (bincount <0.707^$j*$peakcount)\n";
$k=0;
$bin=$ini_size; #setting the starting bin to be the initial size of bin (0.25s)
$new_bincount=0;

#read number of PCUS from pha_files[i] and set to some variable

print "\nPha files to be merged are:\n";
if($j==0){
    print "$pha_files[${i}]\n";
    $new_bincount+=$count_sum2[${i}];
    system "cp $pha_files[$i].pha $sumpha.pha";
    $k++;
}
else{
    while($bin<=$time){
        #check that number of pcus match
	if($pcu_nums[$i] == $pcu_nums[$i+$k]){

        print "$pha_files[${i}+$k] $pcu_nums[$i+$k]\n";
        $new_bincount+=$count_sum2[$i+$k];
        $filelist .= "$pha_files[${i}+$k].pha ";
        $bkgfilelist .= "$pha_files[${i}+$k]_bkg_64ch.pha "; 
        $bin+=$ini_size;
        $k++;

	}else{
	    print "> splitting summation due to pcu number change\n";
	    last;
	}
    }

    #Using sumpha to merge spectras and bkgs
    system "sumpha filelist=\"$filelist\" outfile=$sumpha.pha clobber=yes";
    system "sumpha filelist=\"$bkgfilelist\" outfile=${sumpha}_bkg_64ch.pha clobber=yes";
}

#writing header info to the new file
if($dynamic_rsp){
    if($pha_files[$i] =~ m/[\S]+\_(\d+)/){$num = $1}
  #  unless(-e "${outdir}/${obsid}_${num}.rsp"){
#	die "No response file named ${outdir}/${obsid}_${num}.rsp found!\n";
#    }
    system "fparkey ${outdir}/${obsid}_${num}.rsp $sumpha.pha RESPFILE";
}else{
    system "fparkey ${outdir}/${obsid}_cb.rsp $sumpha.pha RESPFILE";
}
#TODO: make a switch so that user can define if 16s or modelled bkg is written to header
system "fparkey ${outdir}/${obsid}_bkg_16s_64ch.pha $sumpha.pha BACKFILE";



#Doing channel check
chan_check($sumpha);

#Writing right exposures to pha files
$q=0;
$real_bin=0;
while($q<$k){
    $real_bin+=$exposures[$i+$q];
    $q++;
}

#print into pha header
$fkeyprint = `ftlist $sumpha.pha+1 K`;
if($fkeyprint =~ /EXPOSURE=\s+(\S+)\s+\/\s+/){$virtual_bin=$1;}
else {die "Can't get the exposure for $sumpha.pha";}

#print "fparkey $virtual_bin $sumpha.pha EXPOSURE add=no comm='Uncorrected value was $real_bin\'\n";
system "fparkey $virtual_bin $sumpha.pha EXPOSURE add=no comm='Uncorrected value was $real_bin\'";


print "\t\t\t=$new_bincount count\n";


if($new_bincount > 300 && $last_bin eq "false"){
    #if($new_bincount > 500){
    push @sum_pha_files, $sumpha;
}
else{
    print "Bin is not appended to list\n\n"
}




$i=$i+$k;
return $i;

}#sub sumpha ends here


############################################################################
#Channel check <20cnts
sub chan_check
{

my ($sumpha) = @_;

#my $k=0;
my $cc_read="false";
my (@channels, @c_counts);
my $sum_pha_file;
my $c_count;
#my @sumfilelist;
#my $file;

print "Starting to check channel for low photon counts\n";

system "fdump infile=$sumpha.pha+1 outfile=${outdir}/channel.dat columns=\"CHANNEL COUNTS\" rows=\"-\" clobber=yes prhead=no showcol=no\n";
	
	#Chekking that file exists
	unless(-e "${outdir}/channel.dat"){
	    die "File ${outdir}/channel.dat does not exist!\n";
	}
	if( ! open CHANNELS, "<", "${outdir}/channel.dat") {
	    die "Cannot open Input file ${outdir}/channel.dat for reading: $!";
	}

	while(<CHANNELS>){
	    if(/\s+\S+\s+(\S+)\s+(\S+)/){ #1      0    1.000000000000000E+00
	        push @channels, $1;
	        push @c_counts, $2;
	    }
	}#end of channel.dat

close(CHANNELS);


#Marking channels with lower than 20cnts/s BAD starting from channel 15
$i=15;
print "\n\n++++++++++++++$sumpha.pha++++++++++++++\n";
print "Channel\tCount\tMode\n";
while($i < @c_counts){
	print "$channels[$i]\t$c_counts[$i]";
	if($c_counts[$i] < "20" ){
	    print "\t BAD\n";
	    system "grppha infile=\"$sumpha.pha\" outfile=\"$sumpha.pha\" comm=\"BAD $channels[$i]\" tempc=\"exit\" clobber=yes >>grppha_bad.dbg ";
	}
	else{print "\n";}	
	$i++;	
	}

#Formating arrays
@c_counts=();
@channels=();

}#End of channel chek
