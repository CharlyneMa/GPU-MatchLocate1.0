#!/usr/bin/perl -w
#Plot seismograms of the reference and the detected event.
@ARGV == 2 || die "perl $0 event.list pick_num\n";
$EVENT = $ARGV[0];
$pick_num = $ARGV[1];
chomp(@EVENT);
$dir = "/Users/mliu/2019/software/GPU-ML_release1.0";
$templatedir = "$dir/Demo/Template";
$tracedir = "$dir/Demo/Trace";
$input = "$dir/Demo/Template/INPUT";

$pssac = "pssac";

$before = "-1";
$after = "5";
$J = "X8i/6i";
$B = "a5f1/a2f1Sn";

open(EV,"<$EVENT");
@event = <EV>;
close(EV);

$temp1 = "reference";
$temp2 = "object";

shift(@event);
foreach $_(@event){
	chomp($_);
    ($number,$date,$time,$evla,$evlo,$evdp,$mag,$coef,$mad,$template) = split(" ",$_);chomp($template);
	if($number == $pick_num){
	($year,$month,$day) = split("\/",$date);
	($hour,$min,$sec) = split("\:",$time);
	my $otime = $hour*3600+$min*60+$sec;
    
    $title = "$year$month$day$hour$min$sec";
    printf STDERR "$title\n";
	$PS = "$title.ps";
	if(-e $temp1){`rm $temp1/*`;}else{`mkdir $temp1`;}
	if(-e $temp2){`rm $temp2/*`;}else{`mkdir $temp2`;}
	$templateinput = "$input/$template";
	
	open(TM,"<$templateinput") or die"can't open '$templateinput' :$!";
	@sta = <TM>;
	close(TM);

	$num = 0;
	foreach $file1(@sta){
		chomp($file1);
		($station,$t1,$D) = split(" ",$file1);
		$station = sprintf("%-s",$station);
        if(-e "$templatedir/$template/$station" && -e "$tracedir/$year$month$day/$station"){
			`cp $templatedir/$template/$station $temp1/`;
			`cp $tracedir/$year$month$day/$station $temp2/`;
			$num++;
		}
	}
	$nn = $num+1;
	
	foreach $file1(@sta){
		chomp($file1);
		($station,$t0,$D) = split(" ",$file1);
		$station = sprintf("%-s",$station);
		if(-e "$temp1/$station" && -e "$temp2/$station"){
		($jk,$t1,$evla0,$evlo0,$evdp0,$stla,$stlo) = split(" ",`saclst t1 evla evlo evdp stla stlo f "$temp1/$station"`);
		$la = `~/bin/SHIFT -L$evla0/$evlo0/$evdp0 -E$evla/$evlo/$evdp -D$D -S$stla/$stlo`;
		($jk,$dt) = split('=',$la);chomp($dt);
		$ts = $t1 + $before;
		$te = $t1 + $after;
		open(SAC,"|sac>jk");
		print SAC "cut $ts $te\n";
		print SAC "r $temp1/$station\n";
		print SAC "w $temp1/$station.cut\n";
		print SAC "q\n";
		close(SAC);

		$tb = $otime+$t1+$before+$dt;
		open(SAC,"|sac>jk");
		print SAC "rh $temp1/$station.cut\n";
		print SAC "ch b $tb\nwh\n";
		print SAC "q\n";
		close(SAC);
		$t11 = $tb;
		$t22 = $tb-$before+$after;
		open(SAC,"|sac>jk");
		print SAC "cut $t11 $t22\n";
		print SAC "r $temp2/$station\n";
		print SAC "w $temp2/$station.cut\n";
		print SAC "q\n";
		close(SAC);

		}
	}
    unlink jk;
	$mag = sprintf("%2.2f",$mag);
	my $tss = $otime+5;
	my $tee = $otime + 40;

	$R = "$tss/$tee/0/$nn";
	
	my %traces;
     foreach $file1(@sta){
         chomp($file1);
         ($station,$t0,$D) = split(" ",$file1);
         $traces{$station} = $t0;
     }
    
    my @grey; my @red;
	my @keys = sort {$traces{$b}<=>$traces{$a}} keys %traces;
    foreach (@keys) {
         push  @grey, "$temp2/$_";
         push  @red, "$temp1/$_.cut";
     }   
        
    `$pssac -J$J  -R$R -C$tss/$tee -B$B @grey -Ent-3 -K  -M0.3 -r -W1p,grey > $PS`;
    `$pssac -J$J  -R$R  @red -Ent-3 -K  -O -M0.3 -Y0.0i -r -W1p,red >> $PS`;
	
    $nbb = $nn +1.6;
	open(GMT,"|psxy -R -JX -Sv0.03/0.15/0.05 -G255/0/0 -K -O -N >> $PS");
	print GMT "$otime $nbb 270 0.4\n";
	close(GMT);
	$i = 0;
	$tmm = ($tss + $tee)/2;
	&PSTEXT($tmm,-2,13,0,4,MC,"Seconds since $year$month${day}000000.00",$PS);

	$nbb = $nn + 2.0;
	&PSTEXT($tmm,$nbb,15,0,4,MC,"$title (M $mag)",$PS);
	$nbb = $nbb - 1.0;
	&PSTEXT($tmm,$nbb,12,0,4,MC,"(Template event: $template; Mean CC = $coef; MAD = $mad)",$PS);
	$coefsum = 0.0;
	foreach $file(@keys){
		chomp($file);
		$station = $file;
		if(-e "$temp1/$station.cut" && -e "$temp2/$station.cut"){
		$i++;
		`~/bin/ccsacc 2 $temp1/$station.cut $temp2/$station.cut`;
		 $l = `~/bin/lsac 0 $temp2/$station.cut.cc`;
		 chomp($l);
    	($tt,$maxval) = split(" ",$l);
		$maxval = sprintf("%6.3lf",$maxval);
		&PSTEXT($tss-0.8,$i,10,0,4,MC,"$station",$PS);
		&PSTEXT($tee+0.5,$i,10,0,4,MC,"$maxval",$PS);
		$coefsum += $maxval;
		}
	}
	$coefav = $coefsum/@sta;
    #printf "Average coef: %6.4lf  Event coef: %6.4lf\n",$coefav,$coef;
    `psxy -R -J -O /dev/null >> $PS`;
    `rm -r $temp1 $temp2`;
	}
}

$out = "waveforms";
if(-e "$out"){`rm -r $out`}
`mkdir $out`;
`mv *.ps $out`;


sub PSTEXT{
        my($xx, $yy,$textsize, $textangle, $textfont, $just, $text, $ps) = @_;
        open(GMT,"| pstext -R$R -J$J -K -O -N >> $ps");
                print GMT "$xx $yy $textsize $textangle $textfont $just $text\n";
        close(GMT);
}
