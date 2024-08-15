#!/bin/bash

#SBATCH -c 1 
#SBATCH --mem=20G            # memory required, in units of k,M or G, up to 250G.
#SBATCH --gres=tmp:20G       # $TMPDIR space required on each compute node, up to 400G.
#SBATCH -t 24:00:00         # time limit in format dd-hh:mm:ss

# Specify the tasks to run:
#SBATCH --array=1-12 
#SBATCH --output=/nobackup/tmjj24/ddRAD/WGS_titia/slurm-%x.%j.out

# Commands to execute start here

module purge
module load bioinformatics
module load samtools/1.9
module load bcftools
module load plink
module load python/3.9.9
module load r/4.2.1

################################
#### Varibles and set up #######
################################

line_num=$(expr $SLURM_ARRAY_TASK_ID)
echo "$line_num"
#Name of output SNP library

# Get library and genome names

Library_name="WGS_titia"
genome=(/nobackup/tmjj24/ddRAD/Demultiplexed_seq_processing/draft_genomes/HetTit1.0.p.genome.fasta)

# Get chrom names
bioawk -c fastx '{ print $name }' $genome > chrom_names.txt
# Get chrom name equal to job ID
chromosome=$(sed -n "${line_num}p" chrom_names.txt)

echo "Processing database $Library_name using $genome"

# List of BamFiles to use (custom by removing if needed)

# ls /nobackup/tmjj24/ddRAD/WGS_titia/bam/Erandi/*.bam > /home/tmjj24/scripts/Github/Thesis-Phylogeographic-Hetaerina/2_SNP_calling/WGS/WGS_bam_list.txt
# ls /nobackup/tmjj24/ddRAD/WGS_titia/bam/Christophe/*.bam >> /home/tmjj24/scripts/Github/Thesis-Phylogeographic-Hetaerina/2_SNP_calling/WGS/WGS_bam_list.txt
bamFiles=(/home/tmjj24/scripts/Github/Thesis-Phylogeographic-Hetaerina/2_SNP_calling/WGS/${Library_name}_bam_list.txt)
# linkage filter
link_filt=("10000")

#Output directory
output_dir=(/nobackup/tmjj24/ddRAD/Demultiplexed_seq_processing/SNP_libraries_SDC_manuscript/WGS_titia/${Library_name}_r${link_filt}/)

#Make output directories
mkdir -p $output_dir


#####################
#### SNP Calling ####
#####################

cd $output_dir

# Variant calling
# Limit to specific region
# -r $chromosome:26690494-27690494

bcftools mpileup -Ou \
--max-depth 10000 -q 20 -Q 20 \
 -P ILLUMINA --annotate FORMAT/DP,FORMAT/AD \
 -r $chromosome \
-f $genome \
-b $bamFiles | \
bcftools call -m -v -P 1e-6 -f GQ -G - \
-O b -o $TMPDIR/$Library_name.$chromosome.bcf

#######################
#### SNP Filtering ####
#######################

#Name of output SNP library
BCF_FILE=($Library_name.$chromosome)

echo "$BCF_FILE processing"

cd $output_dir

# Indexs file, Im not sure if this is nessacary tbh
bcftools index $TMPDIR/$BCF_FILE.bcf
bcftools index -t $TMPDIR/$BCF_FILE.bcf

# All Varients
echo '0. All varients'
bcftools view -H $TMPDIR/$BCF_FILE.bcf | grep -v -c '^#'

echo "Number of samples"
bcftools query -l $TMPDIR/$BCF_FILE.bcf | grep -v -c '^#'

# Index file

bcftools view -V indels $TMPDIR/$BCF_FILE.bcf -O b > $TMPDIR/$BCF_FILE.snps.bcf

# All snps
echo '1. All snps'
bcftools view -H $TMPDIR/$BCF_FILE.snps.bcf | grep -v -c '^#'

# SNPs genotyped in more than 

# Depth greater than 10, average depth for each sample greater than 10 and less than 200, quality score greater than 60

echo '2. Depth greater than 10, average depth for each sample greater than 10 and less than 200, quality score greater than 60'

bcftools filter -S . -e 'FMT/DP<5' $TMPDIR/$BCF_FILE.snps.bcf | \
bcftools view -e 'AVG(FMT/DP)<5 || AVG(FMT/DP)>200 || QUAL<60' -O b > \
$TMPDIR/$BCF_FILE.snps.NOGTDP5.MEANGTDP5_200.Q60.bcf

bcftools view -H $TMPDIR/$BCF_FILE.snps.NOGTDP5.MEANGTDP5_200.Q60.bcf | grep -v -c '^#'

bcftools view -O z $TMPDIR/$BCF_FILE.snps.NOGTDP5.MEANGTDP5_200.Q60.bcf > $TMPDIR/$BCF_FILE.snps.NOGTDP5.MEANGTDP5_200.Q60.vcf.gz

# Removes SNPs that are not present in more than 80% samples
echo "4. Removing SNPs that arn't genotyped in more than 80% samples"
bcftools view -e 'AN/2<N_SAMPLES*0.8' -O b $TMPDIR/$BCF_FILE.snps.NOGTDP5.MEANGTDP5_200.Q60.bcf > $TMPDIR/$BCF_FILE.snps.NOGTDP5.MEANGTDP5_200.Q60.SAMP0.8.bcf
bcftools view -H $TMPDIR/$BCF_FILE.snps.NOGTDP5.MEANGTDP5_200.Q60.SAMP0.8.bcf | grep -v -c '^#'

# Removing SNPs with a minor allele freq less than 0.05
echo "5. Removing alleles that have a minor allele count of less that 2"
bcftools view --min-ac 2 -O b $TMPDIR/$BCF_FILE.snps.NOGTDP5.MEANGTDP5_200.Q60.SAMP0.8.bcf > $TMPDIR/$BCF_FILE.snps.NOGTDP5.MEANGTDP5_200.Q60.SAMP0.8.MAF2.bcf
bcftools view -H $TMPDIR/$BCF_FILE.snps.NOGTDP5.MEANGTDP5_200.Q60.SAMP0.8.MAF2.bcf | grep -v -c '^#'

bcftools view -O z $TMPDIR/$BCF_FILE.snps.NOGTDP5.MEANGTDP5_200.Q60.SAMP0.8.MAF2.bcf > $TMPDIR/$BCF_FILE.snps.NOGTDP5.MEANGTDP5_200.Q60.SAMP0.8.MAF2.vcf.gz


##### Use output from above to determine appropreate filtering step

echo '6. SNPS randomly thinned to one per ${link_filt} bases'
bcftools +prune -n 1 -N rand -w ${link_filt}bp $TMPDIR/$BCF_FILE.snps.NOGTDP5.MEANGTDP5_200.Q60.SAMP0.8.MAF2.bcf -Ob -o $TMPDIR/$BCF_FILE.snps.NOGTDP5.MEANGTDP5_200.Q60.SAMP0.8.MAF2.rand${link_filt}.bcf
bcftools view -H $TMPDIR/$BCF_FILE.snps.NOGTDP5.MEANGTDP5_200.Q60.SAMP0.8.MAF2.rand${link_filt}.bcf | grep -v -c '^#'
bcftools view -O z $TMPDIR/$BCF_FILE.snps.NOGTDP5.MEANGTDP5_200.Q60.SAMP0.8.MAF2.rand${link_filt}.bcf > $BCF_FILE.snps.NOGTDP5.MEANGTDP5_200.Q60.SAMP0.8.MAF2.rand${link_filt}.vcf.gz

## Then outside of slurm concat all the vcf files using 
# cd $output_dir/
# bcftools concat `ls *.vcf.gz` > ${Library_name}_chr1-12.vcf