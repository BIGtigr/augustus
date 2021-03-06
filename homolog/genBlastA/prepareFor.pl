#!/usr/bin/perl 

use strict;
use File::Basename qw(basename dirname);
use FindBin qw($Bin $Script);
use Getopt::Long;
use Data::Dumper;

# $Bin/alignment.pl

die "Usage:
	perl $0 <net file> <reference gff file> <genewise gff> \n" if(@ARGV < 3);

my $net_file=shift;
my $ref_file=shift;
my $genewise_file=shift;

my $over=0.8;	# set the overlap of two genes to combine.
my $threshold=0;	# set the threshold of homolog
my $over_s=0.1;	# set the overlap percentage of gene wether inside in Synteny

my %ref;
read_gff($ref_file,\%ref);

my %genewise;
read_gff($genewise_file,\%genewise);

=head1
my %map;	# used store combine information	maping list
for my $name(keys %genewise){
	my @a;
	for my $id(sort {$genewise{$name}{$a}->[0] <=> $genewise{$name}{$b}->[0]} keys %{$genewise{$name}}){
		my $p=$genewise{$name}{$id};
		push @a,[@{$p},$id];
	}
	my @b=@{$a[0]};
	for(my $i=1;$i<@a;$i++){
		my $len_short=$b[1]-$b[0] > $a[$i]->[1]-$a[$i]->[0]? $a[$i]->[1]-$a[$i]->[0]+1:$b[1]-$b[0]+1;
		if(($b[1] - $a[$i]->[0]+1)/$len_short <= $over){
			$map{$name}{$b[4]}=$b[4];
			@b=@{$a[$i]};
		}elsif($b[1]-$b[0] > $a[$i]->[1]-$a[$i]->[0]){
			$map{$name}{$a[$i]->[4]}=$b[4];
		}else{
			$map{$name}{$b[4]}=$a[$i]->[4];
			for my $subkey(keys %{$map{$name}}){
				$map{$name}{$subkey}=$a[$i]->[4] if($map{$name}{$subkey} eq $b[4]);
			}
			@b=@{$a[$i]};
		}
	}
	$map{$name}{$b[4]}=$b[4];
}

my $genewise_file_name=basename $genewise_file;
open OUT ,"$genewise_file_name" or die $!;
for my $name(keys %map){
	for my $id(keys %{$map{$name}}){
		print OUT "$name\t$id\t$map{$name}{$id}\n";
	}
}
close OUT;
=cut

open IN,"$net_file" or die $!;
open RESULT,">$net_file.out" or die $!;
open INS,">$net_file.Synteny" or die $!;
my $ref_list="$net_file.ref_list";
my $genewise_list="$net_file.genewise_list";
my $score="$net_file.score";
while(<IN>){
	next if /^#/;
	chomp;
	my $LINE=$_;
	print RESULT "#$LINE\n";
	print INS "#$LINE\n";
	my @a=split /\t/;
	my (%ref_gene,%genewise_gene);
	my ($ref_n,$genewise_n)=(1,1);
	# 0     1    2 3  4    5     6    7  8  9
	#chr,chr_len,s,e,len,strand,chr2,s2,e2,len2
	foreach my $id(sort {$ref{$a[0]}{$a}[0] <=> $ref{$a[0]}{$b}[0]} keys %{$ref{$a[0]}}){
		my $p=$ref{$a[0]}{$id};
		if(($p->[1]-$a[2]+1)/($p->[1]-$p->[0]+1) < $over_s){
			next;
		}elsif(($a[3]-$p->[0]+1)/($p->[1]-$p->[0]+1) < $over_s){
			last;
		}else{
			$ref_gene{$id}=$ref_n;
			$ref_n++;
		}
	}

	my @genewise_tmp;
	foreach my $id(sort {$genewise{$a[6]}{$a}[0] <=> $genewise{$a[6]}{$b}[0]} keys %{$genewise{$a[6]}}){
		my $p=$genewise{$a[6]}{$id};
		if(($p->[1]-$a[7]+1)/($p->[1]-$p->[0]+1) < $over_s){
			next;
		}elsif(($a[8]-$p->[0]+1)/($p->[1]-$p->[0]+1) < $over_s){
			last;
		}else{
			push @genewise_tmp,$id;
		}
	}
	@genewise_tmp=reverse @genewise_tmp if($a[5] eq '-');
	foreach my $aa(@genewise_tmp){
		$genewise_gene{$aa}=$genewise_n;
		$genewise_n++;
	}

	my $flag=0;
	open OUT,">$score" or die $!;
	for my $g_id(keys %genewise_gene){
		my $r_id=$1 if($g_id =~ /(\S+)-D\d+/);
		if(exists $ref_gene{$r_id}){
			print INS "$r_id\t$ref_gene{$r_id}\t$g_id\t$genewise_gene{$g_id}\n";
#			print OUT "$r_id\t$map{$a[6]}{$g_id}\t$genewise{$a[6]}{$g_id}->[2]\n";
			print OUT "$r_id\t$g_id\t$genewise{$a[6]}{$g_id}->[2]\n";
			$flag++;
		}else{
			print INS "0\t0\t$g_id\t$genewise_gene{$g_id}\n";
		}
	}
	close OUT;

	for my $r_id(keys %ref_gene){
#		print "$r_id\n";
		my $r_flag=0;
		my @g_keys=keys %genewise_gene;
		for my $g_id(@g_keys){
			my $g_idid=$1 if($g_id =~ /(\S+)-D\d+/);
			$r_flag=1 if($g_idid eq $r_id);
		}
		print INS "$r_id\t$ref_gene{$r_id}\t0\t0\n" if ($r_flag == 0);
	}


	open OUT,">$ref_list" or die $!;
	my @bb=sort {$ref_gene{$a} <=> $ref_gene{$b}} keys %ref_gene;
	print OUT join("\n",@bb);
	close OUT;

	open OUT,">$genewise_list"or die $!;
	@bb=sort {$genewise_gene{$a} <=> $genewise_gene{$b}} keys %genewise_gene;
	for(@bb){
		my $p_id=$1 if(/(\S+)-D\d+/);
#		print OUT "$map{$a[6]}{$_}\n";
		print OUT "$_\n" if(exists $ref_gene{$p_id});
	}
#	print OUT join("\n",@bb);
	close OUT;

	my $result=`$Bin/alignment.pl $ref_list $genewise_list $score` if ($flag > 0);
	print RESULT $result;
}
close IN;
close RESULT;
close INS;

# `rm -rf $ref_list $genewise_list $score`;

###########################
sub read_gff{
	my ($file,$hash)=@_;
	if($file =~ /\.gz$/){
		open IN,"gzip -dc $file|" or die $!;
	}else{
		open IN,$file or die $!;
	}
	while(<IN>){
		next if /^#/;
		chomp;
		my @a=split /\t/;
		if($a[2] eq 'mRNA' && $a[8]=~/ID=([^;]+)/){
			my $id=$1;
#			if($a[5]=~/^(\d+)/){
#				next if $1 < $threshold;
#			}
			@{$$hash{$a[0]}{$id}}=($a[3]<$a[4])?@a[3,4,5,6]:@a[4,3,5,6];
		}
	}
	close IN;
}
