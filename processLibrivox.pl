#!/bin/perl -w

use strict;

#use Music::Tag (traditional => 1, verbose =>1);
#use MP3::Tag;
#MP3::Tag->config("write_v24"=>0);
use Data::Dumper;
use File::Basename;
#use Audio::FindChunks;
use Cwd qw(abs_path getcwd);
use Path::Class;
use FindBin;
use File::Spec;
use Archive::Zip;
use File::Path;

my $xpath = $FindBin::Bin;

print "$xpath\n";
my $soxPath = "$xpath/../sox-14.4.1/sox.exe";
my $mp3splt = "$xpath/../mp3splt/mp3splt.exe";
my $ffmpeg  = "$xpath/../ffmpeg/ffmpeg.exe";


my $fullDest = file(getDest ("/cygdrive/c/Users/jeremyh/Music/toPhone"));
my $dest = $fullDest->relative(getcwd);
print "DEST: $dest, ->FULL:$fullDest\n";
mkdir ($dest, 0777) || die "cant make dest: $dest\n";
print "DEST:$dest\n";
# iterate through the wildcard-expanded directories
foreach my $arg (@ARGV) {
  foreach (glob $arg) {
    doIt($arg);
  }
}

sub getDest {
	my ($dest) = @_;
	if (-d $dest) {
		$dest =~ s/(\d+)$//;
		my $count = $1;
		if ($count) {
			$count += 1;
		}
		else {
			$count = 1;
		}
		$dest .= $count;
		return getDest($dest);
	}
	else {
		return $dest;
	}
}
		
## process each file in a directory
sub doIt {
    my ($arg) = @_;
	$arg =~ s~/$~~;
	print "DOIT:",$arg,"\n";
    if (-d $arg) {
      opendir(my $dh, $arg) || print "BIG ERROR. Unable to open $arg\n";
        while(readdir $dh) {
	    if ($_ eq '.' || $_ eq '..') {}
	    else {
            	doIt("$arg/$_");
	    }
        }
        closedir $dh;
    }
    else {
        processFile("$arg");
    }
}

my $outputpath;

## determine what needs to be done for a file
sub processFile {
    my ($eh) = @_;
    my $base = basename $eh;

    my $rd = basename (dirname $eh);
    print "DIRNAME: $rd\n";
    $dest =~ s~/$~~;
	print "DEST:$dest:\n";
    $outputpath = $dest."/".$rd;
    print "FILE:",$eh,"\n";

    if ($eh =~ /\.zip$/) {
	processZip($eh);
	return;
    }
    # Read basic info

    my $mp3 = MP3::Tag->new($eh);
    $mp3->get_tags();
    if (exists $mp3->{ID3v2}) {
    	my $id3v2 = $mp3->{ID3v2} if exists $mp3->{ID3v2};
  	my $fr = $id3v2->get_frame("TENC");
	if ($fr && $fr =~ /overdrive/i) {
		processOverdrive($eh,$mp3,$id3v2);
        }
    }
}

sub updatePrimaryTags {
	my ($mp3, $id3, $discpart) = @_;
	my $discnum = $id3->get_frame('TPOS');	
	my $track = $mp3->track;
	if (!$track) {
		$track = $discpart;	
	}
	if (!$discnum) {
		$discnum = $track;
		$id3->add_frame('TPOS',$track);
	}

	print "DISCNUM:$discnum\n";

	my $title = $mp3->title;
	print "TITLE:$title\n";
	$mp3->title_set($discnum."_".$title);	
	#$mp3->update_tags;
  	my $fr = $id3->get_frame("TENC");
	#$id3->change_frame('TENC','soxified');
	#$id3->write_tag();
	print "TRACK:$track\n";
	return $track;
} 

sub speedUp {
	my ($fastfile, $originalfile) = @_; 
	# speedup
	#$originalfile =~ s/ /\\ /g;
	#$fastfile =~ s/ /\\ /g;
	my @cmd = (
		"$soxPath",
		"--show-progress",
		"--volume","1.1",
		"$originalfile", 
        #"-C","64",
		"$fastfile",
		"tempo","1.80");

	print join(" ",@cmd,"\n");
	system (@cmd);

	return;
}

sub splitFile {
	my ($fpath) = @_;
	# split
	my @cmd = (
		"$mp3splt",
		"-s",
		"-p",
		"nt=30",
		"-g",
		'%[@O]',
		"-o",
		'@f_@n',
		$fpath
	);
	print join(" ",@cmd,"\n");
	system (@cmd);
	return;
}

sub processOverdrive {
	my ($file, $mp3, $id3) = @_;
	$file =~ m/Part(\d+)\./;
	my $discpart = $1;
	my $track = updatePrimaryTags($mp3,$id3,$discpart);
	print "OVERDRIVE\n";

	my $base = basename ($file);
	#my $dname = dirname($file);
	if (!-d $outputpath) {
		mkdir ($outputpath,0777) || die "cant  make directory $outputpath";
	}
	my $outfile = $outputpath."/".$track."_".$base;

	print "SPEEDUP: $file -> $outfile\n";
	&speedUp($outfile, $file);
	print "SPLIT: $outfile\n";
	&splitFile($outfile);

	print "DELETE: $outfile\n";
	## delete original sped up file, but keep name for calculating small files
	#unlink($outfile);
	updateTags($outfile,$mp3, $id3);

}


sub updateTags {
	my ($fpath, $mp3, $id3) = @_;

	# update tags

	print "FPATH1:$fpath\n";
	$fpath =~ s/(\.[^\.]*)$//;

	print "FPATH2:$fpath\n";
	my $ext = $1;

	print "EXT:$ext\n";
	my $i;

	for ($i=1;$i<=30;$i++) {
		print "IT\n";
		my $pref = $i;
		if ($i<10) { $pref = "0".$i; }
		my $oldpath = $fpath."_".$pref.$ext;
		my $newpath = $oldpath;
		$newpath =~ s/^(.*\/)?(\d+_)(.*)_(\d+)(\.[^\.]*$)/$1$2$4_$3$5/;
		my $track = $4;
		print "$oldpath -> $newpath\n";
		if (!-f $oldpath) {
			print "$oldpath not found - possibly no more?";
			next;
		}
		rename($oldpath,$newpath);

		setNewTags($newpath, $mp3, $track);
		print "DTS\n";
	}
	print "CLOSE MP3\n";
	$mp3->close();

}


# set the tags on the new partial files

sub setNewTags {
	my ($newpath, $mp3,$track) = @_;
	print "SETNEWTAGS:$newpath\n";

    	my $newmp3 = MP3::Tag->new($newpath);
	$newmp3->config("write_v24",1);
    	$newmp3->get_tags();
    	my $id3 = $mp3->{ID3v2};
    	my $title = $id3->get_frame('TIT2');
	$title =~ s/^(\d+)(_)/$1$2${track}_/;
	my $discnum = $1;

    	my $newid3v2;
	print "A.";
    	if (exists $newmp3->{ID3v2}) {
    		$newid3v2 = $newmp3->{ID3v2};
		$newid3v2->change_frame('TIT2',$title);
		print "CHANGE\n";
	}
	else {
		$newid3v2 = $newmp3->new_tag("ID3v2");
		$newid3v2->add_frame('TIT2',$title);
		print "NEW\n";
	}
	$newid3v2->write_tag();
	#my $id2; = $newmp3->{ID3v1};
	#$id2->title($title);
	print "TITLE: $title\n";
	print "TRACK: $track\n";
	$track = ($discnum-1)*30 + $track;
        $newmp3->title_set($title);
	my $artist = $newmp3->artist;
	$artist =~ s/\/.+$//;
	$newmp3->artist_set($artist);

	$newid3v2->title($title);
	$newid3v2->artist($artist);
	$newmp3->track_set($track);
	print "NEWTRACK:",$track,"\n";
	#my $discnum = $id3->get_frame('TPOS');	
	$newid3v2->change_frame('TPOS',$discnum);


	print "ARTIST: $artist\n";

	$newmp3->update_tags();
	$newmp3->close();

}





sub processZip {
	my ($zipname) = @_;
	print "UZIPPING: $zipname\n";

	my $destinationDirectory = "tmp";
	if (!-d "$destinationDirectory") {
		mkdir ("tmp",0777);
	}

	my $zip = Archive::Zip->new($zipname);
	my @files;

	my $outname = $zipname;
	$outname =~ s/\.zip$//;
	$outname =~ s/_librivox$//;
	$outname =~ s~^.+/~~;
	print "OUTPATH:$outputpath\n";	
	my $outpth = $outputpath."/".$outname;
	if (! -d $outpth) {
		mkpath ($outpth) || die;
	}
	## we need to use a relative path for cygwin sox
	## to get it, we get an absolute path first, then relativize it
	$outpth = abs_path($outpth);
	my $fullOut = file($outpth);
	$outpth = $fullOut->relative(getcwd);
	foreach my $member ($zip->members)
	{
	    next if $member->isDirectory;
	    (my $extractName = $member->fileName) =~ s{.*/}{};
		my $out = ("$destinationDirectory/$extractName");
		print "extracting:",$out,"\n";	
	    	$member->extractToFileNamed( $out);

		## another convoluted relative to absolute to relative
		## may not even be needed, but what the hey
		my $fullOut = file(abs_path($out));
		$out = $fullOut->relative(getcwd);

		my $newfile = $outpth."/".$extractName;

		my $oggOut = mp3ToOgg($out);
	
		## for some reason, librivox mp3s do not work well with sox
		## the new sox version, it only reads a few seconds (but keeps tags)
		## In an older compiled version (sox2) - it converts, but loses tags
		## For this reason, we convert to ogg first	
		speedUp($newfile, $oggOut);
		unlink $out;
		unlink $oggOut;
	}
}

sub mp3ToOgg {
	my ($mp3) = @_;
	my $out = $mp3.".ogg";
	my $cmd = "$ffmpeg -y -i $mp3 -acodec libvorbis -aq -2 $out";
	print `$cmd`;
	return $out;
}
