#! /usr/bin/perl
my $fname;

print "Type file name to lcurve:\n";
chomp($fname = <STDIN>);

#system("heainit");
#system "seextrct infile=$fname gtiorfile=\"-\" gtiandfile=\"-\" outroot=\"$fname\" timecol=\"TIME\" columns=\"Event\" binsz=2 printmode=LIGHTCURVE lcmode=RATE spmode=SUM timemin=INDEF timemax=INDEF timeint=INDEF chmin=INDEF chmax=INDEF chint=INDEF chbin=INDEF";

system "saextrct infile=$fname gtiorfile=APPLY gtiandfile='-' outroot=$fname accumulate=one timecol=TIME columns=\"XeCntPcu0 XeCntPcu1 XeCntPcu2 XeCntPcu3 XeCntPcu4\" binsz=2 printmode=lightcurve lcmode=RATE spmode=SUM timemin=INDEF timemax=INDEF timeint=INDEF chmin=0 chmax=255 chint=INDEF chbin=INDEF";

open(LCPAR1, ">lcurve.par");
print LCPAR1 "1\n$fname.lc\n-\n2\n100000\n$fname.flc\nyes\n$fname.gif/GIF\nexit";
system("lcurve <lcurve.par");
