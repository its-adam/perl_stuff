#!perl -w
# $Id: loan.pl,v 1.8 2011/02/07 19:49:42 alrakest Exp $
# Copyright 2002 Intel Corporation, Confidential Information
# $Log: loan.pl,v $
# Revision 1.8  2011/02/07 19:49:42  alrakest
# updated to better handle just 1 principle value, regardless of rate values. works
#
# Revision 1.7  2010/07/13 19:47:46  alrakest
# added cmd line option to print values with commas
#
# Revision 1.6  2010/07/13 19:02:52  alrakest
# fixed the line count bug, it was 2 things: only want to say at new page once per block instead of every entry per block and needed to have block count start with 0 instead of 1.  added cmd line option to not print the CMD line in header
#
# Revision 1.5  2010/07/12 23:19:52  alrakest
# added user overrides for column count and line count.  column count works fine.  line count is (and has been i guess) broken.  if it's not 75 then printing goes haywire
#
# Revision 1.4  2010/07/01 21:30:36  alrakest
# made it so that it will always compute the top_principle and top_rate values even if the delta_* makes it go over.  just computes it once though
#
# Revision 1.3  2010/06/30 20:22:09  alrakest
# adding the ability to format the print layout for my printcs -r command.  not enabled with sorting yet
#
# Revision 1.2  2010/06/29 19:40:24  alrakest
# Added numerical sort
#
# Revision 1.1  2010/06/29 19:17:15  alrakest
# initial version. works.
#

use strict;
use Getopt::Long;
use POSIX;

$| = 1;

my $SCRIPT = $0;
my $CMD = $SCRIPT . " @ARGV";
my $term = 360;
my $principle = 200000;
my $top_principle = 600000;
my $principle_delta = 50000;
my $rate = 6;
my $top_rate = 7;
my $rate_delta = .25;
my $payment = 0;
my $HELP = 0;
my $sort_payment = 0;
my $just_one_value = 0;
my $debug = 0;
my $formatPrintLayout = 0;
my $max_column_count = 0;
my $max_line_count = 0;
my $no_cmd_line_header = 0;
my $use_commas = 0;
my $options = &GetOptions('help!'             => \$HELP,
                          'term:s'            => \$term,
			  'principle:s'       => \$principle,
			  'top_principle:s'   => \$top_principle,
			  'delta_principle:s' => \$principle_delta,
			  'rate:s'            => \$rate,
			  'top_rate:s'        => \$top_rate,
			  'delta_rate:s'      => \$rate_delta,
			  'sort_payment!'     => \$sort_payment,
			  'do_1!'             => \$just_one_value,
			  'debug!'            => \$debug,
			  'format_page!'      => \$formatPrintLayout,
			  'max_col_count:s'   => \$max_column_count,   #start with 1, not 0 :)
			  'max_line_count:s'  => \$max_line_count,
			  'no_cmd_line!'      => \$no_cmd_line_header,
			  'use_commas!'       => \$use_commas,
                          );
if($HELP) { &USAGE; }

if($just_one_value) {
    $top_principle = $principle;
    $principle_delta = 1;
    $top_rate = $rate;
    $rate_delta = 1;
}

#These are for formatting the print layout
my $linesPerPage = ($max_line_count) ? $max_line_count : 75;       #Landscape Mode.  let the user override the value though (34 lines in word)
my $headerLinesPerPage = ($no_cmd_line_header) ? 2 : 3;  #CMD line + column headers (2 lines)
my $entriesPerPage = $linesPerPage - $headerLinesPerPage;  #MAX for landscape mode.  will be adjusted on the fly
my $dataPerPage;
my $footerLinesPerPage;
my $columnsPerPage = ($max_column_count) ? $max_column_count-1 : 4;      #can fit 5 columns in landscape mode.  count from 0. let the user override the value though (4 columns in word)
my $blocksPerPage;
my($linesPerBlock, $entriesPerBlock, $totalBlocks, $totalEntries);


my $PRINCIPLE = $principle;
my $RATE = $rate;  #save this so that i can use it to reset the rate on each principle
print "${CMD}\n" unless($formatPrintLayout || $no_cmd_line_header);
printf            "principle   rate    term   payment\n" unless($formatPrintLayout);
printf "%-34s\n", "----------------------------------" unless($formatPrintLayout);
if($debug) {
    print "term: $term\n";
    print "principle: $principle\n";
    print "top_pr: $top_principle\n";
    print "rate: $rate\n";
    print "top_rate: $top_rate\n";
    print "delta_p: $principle_delta\n";
    print "rate_p:  $rate_delta\n";
}
my $payhash = {};
my $index = 1;
my $thisIsLastPrinciple = 0;
while(($principle <= $top_principle) && ($thisIsLastPrinciple < 2))
{
    my $thisIsLastRate = 0;
    while(($rate <= $top_rate) && ($thisIsLastRate < 2))
    {
	my $r1 = $rate/100;  my $r = $r1/12;

# $payment = $principle*$r*(1 + $r)^$term)/((1 + $rate)^$term - 1);
	my $numer = $principle*$r*(1 + $r)**$term;
	my $demoner = ((1 + $r)**$term) - 1;
	$payment = sprintf "%.2f", $numer / $demoner;
	unless($formatPrintLayout) {
	    if(!$sort_payment) {
		printf "%-9d   %-4.3f   %-4s   %-8.2f\n", $principle, $rate, $term, $payment;
	    }
	    else {
		if(!exists $payhash->{$payment}) {
		    $payhash->{$payment}->{rate} = $rate;
		    $payhash->{$payment}->{term} = $term;
		    $payhash->{$payment}->{princ} = $principle;
		    $payhash->{$payment}->{princWithCommas} = $principle;
		    $payhash->{$payment}->{princWithCommas} = &addCommas($payhash->{$payment}->{princWithCommas});
		}
	    }
	}
	if($formatPrintLayout) {
	    $payhash->{$index}->{rate} = $rate;
	    $payhash->{$index}->{term} = $term;
	    $payhash->{$index}->{princ} = $principle;
	    $payhash->{$index}->{payment} = $payment;
	    $payhash->{$index}->{princWithCommas} = $principle;
	    $payhash->{$index}->{princWithCommas} = &addCommas($payhash->{$index}->{princWithCommas});
	    $payhash->{$index}->{paymentWithCommas} = $payment;
	    $payhash->{$index}->{paymentWithCommas} = &addCommas($payhash->{$index}->{paymentWithCommas});
	    $index++;
	}
	$rate += $rate_delta;
	if(($rate >= $top_rate)  && (!$just_one_value)) {
	    $rate = $top_rate;
	    $thisIsLastRate++;
	}
    }
    my $lastPrinciple = $principle;
    $principle += $principle_delta;
    if(($principle >= $top_principle) && (!$just_one_value)) {
	$principle = $top_principle;
	$thisIsLastPrinciple++;
    }
    if($lastPrinciple == $principle) {
	$thisIsLastPrinciple++;
    }
    $rate = $RATE;
    if(!$sort_payment && !$formatPrintLayout) {
	print "\n";
    }
}

if($sort_payment && !($formatPrintLayout)) {
    print "\n";
    foreach my $paymt (sort numerically keys %$payhash) {
	printf "%-9d   %-4.3f   %-4s   %-8.2f\n", $payhash->{$paymt}->{princ}, $payhash->{$paymt}->{rate}, $payhash->{$paymt}->{term}, $paymt unless($use_commas);
	my $paymtWithCommas = $paymt;  $paymtWithCommas = &addCommas($paymtWithCommas);
	printf "%-9s   %-4.3f   %-4s   %-8s\n", $payhash->{$paymt}->{princWithCommas}, $payhash->{$paymt}->{rate}, $payhash->{$paymt}->{term}, $paymtWithCommas if($use_commas);
    }
}

if($formatPrintLayout) {
    $totalEntries = scalar keys %{$payhash};

    #don't want to break a block.  # of lines per block == #rates :: only applies to !sort
    $entriesPerBlock = (($top_rate - $RATE) / $rate_delta) + 1;
    $entriesPerBlock = &POSIX::ceil(($top_rate - $RATE) / $rate_delta) if($entriesPerBlock =~ /\d+\.\d+/);
    $linesPerBlock = $entriesPerBlock + 1;  #to account for the blank line spacer

    #this should always be an integer by construction...perhaps i should check that condition?
    $totalBlocks = $totalEntries / $entriesPerBlock;

    #if it's % == 0 [eg. can fit an integer number of blocks] then we can leave entriesPerPage alone.  Else we have to modify it
    #it's not absolute # of entries per page. it is # of entry lines per page (data + spacer)
    $entriesPerPage = ($entriesPerPage % $linesPerBlock) ? (&POSIX::floor($entriesPerPage / $linesPerBlock))*$linesPerBlock  : $entriesPerPage;
    $dataPerPage = (&POSIX::floor($entriesPerPage / $linesPerBlock))*$entriesPerBlock;  #does not include the spacer between blocks.  only data entries

    #usable_data_space_per_page / lines_per_block
    $blocksPerPage = &POSIX::floor($entriesPerPage / $linesPerBlock);

    #There will be a footer of total_page_lines -  lines_of_header - acutal_data_lines
    $footerLinesPerPage = $linesPerPage - $headerLinesPerPage - $entriesPerPage;

    my $totalLinesPrinted  = 0;   #absolute line count.  includes headers and whitespace.
    my $totalEntriesPrinted = 0;  #absolute data entry count.  1 line can have up to $columnsPerPage data entries
    my $blocksPrinted = 0;   #absolute block count. count from 1.  start at 0 since we update it post block being printed
    my $pagesPrinted = 1;    #absolute page count.  count from 1.  start at 1 since we update it post page being printed
    my $needHeader = 1;      #need headers at the start of every page
    my $curLine = 2;

#    print "linesPerPage: $linesPerPage\theaderLinesPerPage: $headerLinesPerPage\tentriesPerPage: $entriesPerPage\tfooterLinesPerPage: $footerLinesPerPage\ttotalEntries: $totalEntries\tentriesPerBlock: $entriesPerBlock\tlinesPerBlock: $linesPerBlock\ttotalBlocks: $totalBlocks\tdataPerPage: $dataPerPage\ttotalEntries: $totalEntries\tblocksPerPage: $blocksPerPage\n";

    while(($totalEntriesPrinted) < $totalEntries) {
#	print "'$curLine' ";
#	print "'$totalEntriesPrinted vs $totalEntries' ";
#	print "$totalLinesPrinted $blocksPrinted $blocksPerPage $needHeader '";

	my $currentPage = $pagesPrinted-1;  #want to count the pages from 0 for algorithm
	my($currentLinesPrinted, $currentEntriesPrinted) = &buildLine($curLine, $needHeader, $currentPage);
#	my($currentLinesPrinted, $currentEntriesPrinted) = &buildLine($curLine, $needHeader, $pagesPrinted);

	$totalLinesPrinted += $currentLinesPrinted;
	$totalEntriesPrinted += $currentEntriesPrinted;
#	print "blocksPrinted: $blocksPrinted\n" if($currentLinesPrinted == 2);
	$blocksPrinted++ if($currentLinesPrinted == 2);
#	print "blocksPrinted: $blocksPrinted\n" if($currentLinesPrinted == 2);
	#add in the footer if we're done with a page
	if(($blocksPrinted == $blocksPerPage * $pagesPrinted) && (!($totalEntriesPrinted % $entriesPerBlock))){
#	    print "blocksPrinted: $blocksPrinted\tblocksPerPage: $blocksPerPage\tpagesPrinted: $pagesPrinted\n";
	    foreach (1..$footerLinesPerPage) {
		print "\n";
		$totalLinesPrinted++;
	    }
	}
	
	$needHeader = ($totalLinesPrinted == $linesPerPage * $pagesPrinted) ? 1 : 0;   #if we are on a new page then need headers
	$pagesPrinted++ if($needHeader);

	$curLine++;   #what is curLine ?????
    }
}

sub addCommas {
    my($number) = @_;
    while($number =~ s/^(-?\d+)(\d\d\d)/$1,$2/) { 1; }
    return $number;
}

sub numerically {
    $a <=> $b
}


sub buildLine {
    my ($curLine, $needHeader, $currentPage) = @_;
    my $linesPrinted = 0;
    my $entriesPrinted = 0;
    #Headers
    if($needHeader) {
	print "${CMD}\n" unless($no_cmd_line_header);
	foreach my $curColumn(0..$columnsPerPage) {
	    my $index = ($curLine-1) + ($curColumn*$blocksPerPage*$entriesPerBlock);
	    $index += ($dataPerPage * $columnsPerPage * $currentPage);  #constant add-on based on page number
	    if(exists($payhash->{$index})) {
		printf("%-5s", "") unless($curColumn == 0);
		printf            "principle   rate    term   payment ";
	    }
	    else { last; }
	}
	print "\n";
	foreach my $curColumn(0..$columnsPerPage) {
	    my $index = ($curLine-1) + ($curColumn*$blocksPerPage*$entriesPerBlock);
	    $index += ($dataPerPage * $columnsPerPage * $currentPage);  #constant add-on based on page number
	    if(exists($payhash->{$index})) {
		printf("%-5s", "") unless($curColumn == 0);
		printf "%-35s", "-----------------------------------";
	    }
	    else { last; }
	}
	print "\n";
	$linesPrinted += $headerLinesPerPage;
    }
    #Data
    foreach my $curColumn(0..$columnsPerPage) {
	my $index = ($curLine-1) + ($curColumn*$blocksPerPage*$entriesPerBlock);
	$index += ($dataPerPage * $columnsPerPage * $currentPage);  #constant add-on based on page number
	if(exists($payhash->{$index})) {
	    printf("%-5s", "") unless($curColumn == 0);
	    printf "%-9d   %-4.3f   %-4s   %-8.2f", $payhash->{$index}->{princ}, $payhash->{$index}->{rate}, $payhash->{$index}->{term}, $payhash->{$index}->{payment} unless($use_commas);
	    printf "%-9s   %-4.3f   %-4s   %-8s", $payhash->{$index}->{princWithCommas}, $payhash->{$index}->{rate}, $payhash->{$index}->{term}, $payhash->{$index}->{paymentWithCommas} if($use_commas);
	    $entriesPrinted++;
	}
	else { last };
    }
    print "\n";
    $linesPrinted++;
    if(exists($payhash->{$curLine}->{princ}) && exists($payhash->{$curLine-1}->{princ})) {
	if(($curLine-1 > 0) && ($payhash->{$curLine-1}->{princ} != $payhash->{$curLine}->{princ})) {
	    print "\n";   #spacer between blocks; accounted for in $linesPerBlock
	    $linesPrinted++;
	}
    }
    return ($linesPrinted, $entriesPrinted);
}

sub USAGE
{
    print "You asked for help\n\n";
    print "\t-help              ask for this help\n";
    print "\t-principle         give an initial loan value\n";
    print "\t                       default is 200,000\n";
    print "\t-top_principle     give a max loan value\n";
    print "\t                       default is 600,000\n";
    print "\t-delta_principle   give an increment loan value\n";
    print "\t                       default is 50,000\n";
    print "\t-rate               give an initial interest rate (%)\n";
    print "\t                       default is 6\n";
    print "\t-top_rate          give a max interest rate\n";
    print "\t                       default is 8\n";
    print "\t-delta_rate        give an increment rate value\n";
    print "\t                       default is .25\n";
    print "\t-term              give the length of the loan (months)\n";
    print "\t                       default is 360\n";
    print "\t-sort_payment      output will be sorted by payment amount\n";
    print "\t                       default is OFF (print as a table)\n";
    print "\t-do_1              will just do one point instead of many\n";
    print "\t                       default is OFF\n";

    print "\nExample:\n";
    print "  $SCRIPT [-term -principle -top_principle -delta_principle -rate -top_rate -delta_rate -sort_payment]\n";
    print "  $SCRIPT -term 360 -p 400000 -top_p 600000 -delta_p 20000 -rate 6.5 -top_r 7.25 -delta_r .10 -s\n";
    print "  $SCRIPT -term 360 -p 400000 -rate 6.5 -do_1\n";
    exit(1);
}
