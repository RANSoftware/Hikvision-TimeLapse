#!/usr/bin/perl -

use Date::Format;

my ($inputDir, $outputDir) = @ARGV;

if (not defined $inputDir) {
  die "Need input directory\nUsage extract_capture.pl inputdir outputdir";
}

if (not defined $outputDir) {
  die "Need output directory\nUsage extract_capture.pl inputdir outputdir";
}

print "\n************* EXTRACTION DATE AND TIME LIMITS *************\n";
print "\nDate and time format example YYYYMMDDHHMMSS: 20181225221508\n";
print "\nEnter START date and time (or enter 1 to start from the\nfirst available image or leave empty if you don't want to use\na date and time limit): ";
my $inputStartDate = <STDIN>;
chomp $inputStartDate;

$nowEndDate = time2str("%Y%m%d%H%M%S", time());

if ($inputStartDate != "") {
	print "\nEnter END date and time (or enter 1 to use current date and\ntime (this will extract until the last image), or leave empty\nif you don't want to use a date and time limit): ";
	our $inputEndDate = <STDIN>;
	chomp $inputEndDate;
	if ($inputEndDate == 1) {
		$inputEndDate = $nowEndDate;
	}
}

print "\n************* OUTPUT JPG FILES NAMING OPTIONS *************\n";
print "\nEnter 1 for Image_YYYY_MM_DD-HH_MM_SS-DayName.jpg\nEx: Image_2018_12_25-22_15_08-Tue.jpg\n";
print "\nEnter 2 for Image_YYYYMMDDHHMMSS-DayNumber.jpg\nEx: Image_20181225221508-2.jpg\n";
my $outputDateFormat = <STDIN>;
chomp $outputDateFormat;

$maxRecords = 4096;
$recordSize = 80;

open (FH,$inputDir . "/index00p.bin") or die;
read (FH,$buffer,1280);
#read (FH,$buffer,-s "index00.bin");

($modifyTimes, $version, $picFiles, $nextFileRecNo, $lastFileRecNo, $curFileRec, $unknown, $checksum) = unpack("Q1I1I1I1I1C1176C76I1",$buffer);
#print "$modifyTimes, $version, $picFiles, $nextFileRecNo, $lastFileRecNo, $curFileRec, $unknown, $checksum\n";

$currentpos = tell (FH);
$offset = $maxRecords * $recordSize;
$fullSize = $offset * $picFiles;

for ($i=0; $i<$fullSize; $i++) {
		seek (FH, $i, 0); #Use seek to make sure we are at the right location, 'read' was occasionally jumping a byte
		$Headcurrentpos = tell (FH);
		read (FH,$Headbuffer,80); #Read 80 bytes for the record
		#print "************$Headcurrentpos***************\n";
				
		($Headfield1, $Headfield2, $Headfield3, $Headfield4, $Headfield5, $Headfield6, $HeadcapDate, $Headfield8, $Headfield9, $Headfield10, $Headfield11, $Headfield12, $Headfield13, $Headfield14, $HeadstartOffset, $HeadendOffset) = unpack("I*",$Headbuffer);
				
		#print "$Headercurrentpos: $Headfield1, $Headfield2, $Headfield3, $Headfield4, $Headfield5, $Headfield6, $HeadcapDate, $Headfield8, $Headfield9, $Headfield10, $Headfield11, $Headfield12, $Headfield13, $Headfield14, $HeadstartOffset, $HeadendOffset\n";
		if ($HeadcapDate > 0 and $Headfield8 == 0 and $Headfield9 > 0 and $Headfield10 == 0 and $Headfield11 == 0 and $Headfield12 == 0 and $Headfield13 == 0 and $Headfield14 == 0 and $HeadstartOffset > 0 and $HeadendOffset > 0)
		{
			$fullSize = 1;
			$headerSize = $Headcurrentpos - $recordSize;
			print "HeaderSize: $headerSize\n";
		}
}

for ($i=0; $i<$picFiles; $i++) {
	$newOffset = $headerSize + ($offset * $i);
	seek (FH, $newOffset, 0);
	$picFileName = "hiv" . sprintf("%05d", $i) . ".pic";
	print "PicFile: $picFileName at $newOffset\n";
	#<STDIN>;
	open (PF, $inputDir . "/" . $picFileName) or die;
	binmode(PF);
		
	for ($j=0; $j<$maxRecords; $j++) {
		$recordOffset = $newOffset + ($j * $recordSize); #get the next record location
		seek (FH, $recordOffset, 0); #Use seek to make sure we are at the right location, 'read' was occasionally jumping a byte
		$currentpos = tell (FH);
		read (FH,$buffer,80); #Read 80 bytes for the record
		#print "************$currentpos***************\n";
				
		($field1, $field2, $field3, $field4, $field5, $field6, $capDate, $field8, $field9, $field10, $field11, $field12, $field13, $field14, $startOffset, $endOffset) = unpack("I*",$buffer);
		$formatted_start_time = time2str("%C", $capDate, -0005);
		if ($outputDateFormat == 1) {
			$fileDate = time2str("%Y_%m_%d-%H_%M_%S", $capDate, -0005);
			$fileDayofWeek = time2str("%a", $capDate, -0005);
		}
		elsif ($outputDateFormat == 2) {
			$fileDate = time2str("%Y%m%d%H%M%S", $capDate, -0005);
			$fileDayofWeek = time2str("%w", $capDate, -0005);
		}
		else {
			$fileDate = time2str("%Y_%m_%d-%H_%M_%S", $capDate, -0005);
			$fileDayofWeek = time2str("%a", $capDate, -0005);
		}
		$limitFileDate = time2str("%Y%m%d%H%M%S", $capDate, -0005);
		
		#print "$currentpos: $field1, $field2, $field3, $field4, $field5, $field6, $capDate, $field8, $field9, $field10, $field11, $field12, $field13, $field14, $startOffset, $endOffset\n";
		
		if ($inputStartDate != "" and $inputEndDate != "") {
			if ($capDate > 0 and $limitFileDate >= $inputStartDate and $limitFileDate <= $inputEndDate) {
				$jpegLength = ($endOffset - $startOffset);
				$fileSize = $jpegLength / 1024;
				$fileName = "Image_${fileDate}-${fileDayofWeek}.jpg";
				
				unless (-e $outputDir."/".$fileName) {
					if ($jpegLength > 0) {
						seek (PF, $startOffset, 0);
						read (PF, $singlejpeg, $jpegLength) or die;
						if ($singlejpeg =~ /[^\0]/) {
							print "POSITION ($currentpos): $formatted_start_time - OFFSET:($startOffset - $endOffset)\nFILE NAME: $fileName FILE SIZE: ". int($fileSize)." KB\n\n";
							open (OUTFILE, ">". $outputDir."/".$fileName);
							binmode(OUTFILE);
							print OUTFILE ${singlejpeg};
							close OUTFILE;
						}
					}
				}
			}
		} 
		else {
			if ($capDate > 0) {
				$jpegLength = ($endOffset - $startOffset);
				$fileSize = $jpegLength / 1024;
				$fileName = "Image_${fileDate}-${fileDayofWeek}.jpg";
				
				unless (-e $outputDir."/".$fileName) {
					if ($jpegLength > 0) {
						seek (PF, $startOffset, 0);
						read (PF, $singlejpeg, $jpegLength) or die;
						if ($singlejpeg =~ /[^\0]/) {
							print "POSITION ($currentpos): $formatted_start_time - OFFSET:($startOffset - $endOffset)\nFILE NAME: $fileName FILE SIZE: ". int($fileSize)." KB\n\n";
							open (OUTFILE, ">". $outputDir."/".$fileName);
							binmode(OUTFILE);
							print OUTFILE ${singlejpeg};
							close OUTFILE;
						}
					}
				}
			}
		}
	}
	close (PF);
}
close FH;
