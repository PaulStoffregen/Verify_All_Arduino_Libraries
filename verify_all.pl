#! /usr/bin/perl

use List::Util 'shuffle';

$dir = '/home/paul/teensy/arduino-1.8.4';
$sketchbook = '/home/paul/teensy/sketch';

$n = 0;
$list[$n++] = 'Teensy 3.2 / 3.1';
$list[$n++] = 'Teensy LC';
$list[$n++] = 'Teensy 3.5';
$list[$n++] = 'Teensy 3.6';
$list[$n++] = 'Teensy 3.0';
$list[$n++] = 'Teensy 2.0';
$list[$n++] = 'Teensy++ 2.0';

#$opt = 'Teensy 3.6, USB Type = Serial, CPU Speed = 120 MHz, Optimize = Faster with LTO';
#$opt = 'Teensy 3.6, Optimize = Fastest with LTO';

open F, "find $dir/hardware/teensy/avr/libraries -name '*.ino' -o -name '*.pde' |";
$examples_count = 0;
while (<F>) {
	chop;
	next unless /([^\/]+)\/([^\/]+)\.(ino|pde)$/;
	next unless $1 eq $2;  # only build main sketch, not other files
	next if ($3 eq 'pde') && /\/Processing\//; # ignore Processing code
	$examples[$examples_count++] = $_;
}
close F;
open F, "find $dir/examples -name '*.ino' -o -name '*.pde' |";
while (<F>) {
	chop;
	next unless /([^\/]+)\/([^\/]+)\.(ino|pde)$/;
	next unless $1 eq $2;  # only build main sketch, not other files
	next if ($3 eq 'pde') && /\/Processing\//; # ignore Processing code
	$examples[$examples_count++] = $_;
}
close F;
open F, "find $sketchbook/libraries -name '*.ino' -o -name '*.pde' |";
while (<F>) {
	chop;
	next unless /([^\/]+)\/([^\/]+)\.(ino|pde)$/;
	next unless $1 eq $2;  # only build main sketch, not other files
	next if ($3 eq 'pde') && /\/Processing\//; # ignore Processing code
	$examples[$examples_count++] = $_;
}
close F;
print "Testing $examples_count examples\n";


foreach $opt (@list) {
	my @config, @pref;
	my %userconfig, %menu, %setting;
	my $boardspec, $prefcount;
	undef $boardspec;
	undef %menu;
	undef %setting;
	undef %userconfig;

	@config = split /,[ ]*/, $opt;
	#print "board = $config[0]\n";
	for (my $i=1; $i < @config; $i++) {
		my @f = split /\s*=\s*/, $config[$i];
		if (@f == 2) {
			$userconfig{$f[0]} = $f[1];
		}
	}
	$prefcount = 0;
	open B, "$dir/hardware/teensy/avr/boards.txt";
	while (<B>) {
		chop;
		if (/^menu\.([a-zA-Z0-9-]+)=(.+)/) {
			# top level menu name
			$menu{$1} = $2;
		}
		if (/^([a-zA-Z0-9-]+)\.name=(.+)/) {
			# board name
			if ($2 eq $config[0]) {
				$boardspec = $1;
				#print "boardspec = $boardspec\n";
			}
		}
		if (defined($boardspec) && /^$boardspec\./) {
			$_ = $';
			# line for selected board
			if (/^menu\.([a-zA-Z0-9-]+)\.([a-zA-Z0-9-]+)=(.+)/) {
				# menu item name
				if (defined($menu{$1})) {
					#print "  menu item: $1 . $2 -> $3\n";
					if (!defined($setting{$1}) && !defined($userconfig{$menu{$1}})) {
						$setting{$1} = $2; # default setting
						#print "    DEFAULT\n";
					} elsif ($userconfig{$menu{$1}} eq $3) {
						$setting{$1} = $2; # explicitly set option
						#print "    SELECTED\n";
					}
				}
			}
			if (/^menu\.([a-zA-Z0-9-]+)\.([a-zA-Z0-9-]+)\.(.+)/) {
				if (defined($menu{$1}) && defined($setting{$1}) && $setting{$1} eq $2) {
					#print "  menu def:  $1 . $2 -> $3\n";
					my $val = $3;
					$val = "\"$val\"" if $val =~ /\s/;
					$pref[$prefcount++] = $val;
				}
			}
		}
	}
	close B;

	foreach $file (@examples) {
		#print "\n";

		my $cmd = "$dir/arduino --verify --board teensy:avr:$boardspec";
		for ($i=0; $i < $prefcount; $i++) {
			$cmd .= "  --pref $pref[$i]";
		}
		$cmd .= " $file";
		$commandlist[$commandlist_count++] = $cmd;
	}
}

print "Commands created: ", @commandlist + 0, "\n";

# read all previously run commands, to avoid duplication of effort
open OKAY, "verify_all.okay.txt";
my @del_indexes = undef;
while (<OKAY>) {
	next if /^\s/;
	chop;
	my $prev = $_;
	my @del_indexes = reverse(grep { $commandlist[$_] eq $prev } 0..$#commandlist);
	foreach $item (@del_indexes) { splice (@commandlist, $item, 1); }
}
close OKAY;
open WARN, "verify_all.warnings.txt";
while (<WARN>) {
	next if /^\s/;
	chop;
	my $prev = $_;
	my @del_indexes = reverse(grep { $commandlist[$_] eq $prev } 0..$#commandlist);
	foreach $item (@del_indexes) { splice (@commandlist, $item, 1); }
}
close WARN;
open ERR, "verify_all.errors.txt";
while (<ERR>) {
	next if /^\s/;
	chop;
	my $prev = $_;
	my @del_indexes = reverse(grep { $commandlist[$_] eq $prev } 0..$#commandlist);
	foreach $item (@del_indexes) { splice (@commandlist, $item, 1); }
}
close ERR;
open IGNORE, "verify_all.ignore.txt";
while (<IGNORE>) {
	next if /^\s/;
	chop;
	my $prev = $_;
	my @del_indexes = reverse(grep { $commandlist[$_] eq $prev } 0..$#commandlist);
	foreach $item (@del_indexes) { splice (@commandlist, $item, 1); }
}
close IGNORE;

open INCOMPATIBLE, "verify_all.incompatible";
while (<INCOMPATIBLE>) {
	chop;
	next if /^\#/;
	my @pattern = split;
	my $num = @pattern + 0;
	next unless $num > 0;
	#print "incompatible pattern with $num elements: $_\n";
	my @del_indexes = undef;
	for ($i=0; $i < @commandlist; $i++) {
		my $count = 0;
		foreach $str (@pattern) {
			$count++ if index($commandlist[$i], $str) >= 0;
		}
		push(@del_indexes, $i) if $count == $num;
		#print "  match: $commandlist[$i]\n" if $count == $num;
	}
	if (@del_indexes > 0) {
		@del_indexes = reverse(@del_indexes);
		foreach $item (@del_indexes) { splice (@commandlist, $item, 1); }
	}
}
close INCOMPATIBLE;

@commandlistrandom = shuffle(@commandlist);

print "Commands to run:  ", @commandlistrandom + 0, "\n";

#while (@commandlist) {
#	my $i = int(rand() * @commandlist);
#	push @commandlistrandom, $commandlist[i];
#	splice(@commandlist, $i, 1);
#}

foreach $cmd (@commandlistrandom) {
	#print "$cmd\n";

	my $file;
	$file = $' if $cmd =~ / $dir\/hardware\/teensy\/avr\/libraries\//;
	$file = $' if $cmd =~ / $dir\/examples\//;
	$file = $' if $cmd =~ / $sketchbook\/libraries\//;
	$cmd =~ /--board teensy:avr:([a-zA-Z0-9]+)/;
	my $board = $1;

	$fileshort = $file;
	$fileshort = $' if $file =~ /$dir\/hardware\/teensy\/avr\/libraries\//;

	print "$board  $file\n";

	pipe(READER, WRITER) ;
	my $pid = fork();
	if ($pid == 0) {
		close(READER) ;
		open(STDERR,">&", WRITER) or die "Cannot duplicate STDERR";
		open(STDOUT,">&", WRITER) or die "Cannot duplicate STDOUT";
		exec($cmd) or exit(1);
	}
	close(WRITER);
	#my @output = <READER>;
	#print @output;
	$errors = $warnings = 0;
	$text = '';
	while (<READER>) {
		$errors++ if / error: /;
		$warnings++ if / warning: /;
		if ($errors || $warnings) {
			$text .= "\t$_";
			#print "\t$_";
		}
	}
	if ($errors) {
		print $text;
		open ERR, ">>", "verify_all.errors.txt";
		print ERR "  $board  $file\n";
		print ERR "$cmd\n";
		print ERR $text;
		print ERR "\n\n";
		close ERR;
	} elsif ($warnings) {
		print $text;
		open WARN, ">>", "verify_all.warnings.txt";
		print WARN "  $board  $file\n";
		print WARN "$cmd\n";
		print WARN $text;
		print WARN "\n\n";
		close WARN;
	} else {
		open OKAY, ">>", "verify_all.okay.txt";
		print OKAY "  $board  $file\n";
		print OKAY "$cmd\n";
		print OKAY $text;
		print OKAY "\n";
		close OKAY;
	}
}














