#!/bin/bash

#SBATCH -c 1 
#SBATCH --mem=20G            # memory required, in units of k,M or G, up to 250G.
#SBATCH --gres=tmp:20G       # $TMPDIR space required on each compute node, up to 400G.
#SBATCH -t 24:00:00         # time limit in format dd-hh:mm:ss

# Specify the tasks to run:
#SBATCH --array=7  # Create 6 tasks, numbers 1 to 6
#SBATCH --output=slurm-%x.%j.out

# Commands to execute start here

#Modules
module load r/4.2.1
module load bioinformatics
module load bcftools

#Name of output SNP library

line_num=$(expr $SLURM_ARRAY_TASK_ID)

echo "$line_num"

# Get library and genome names

Library_name=$(sed -n "${line_num}p" /home/tmjj24/scripts/Github/Thesis-Phylogeographic-Hetaerina/2_SNP_calling/library_combinations/library_name)
genome=$(sed -n "${line_num}p" /home/tmjj24/scripts/Github/Thesis-Phylogeographic-Hetaerina/2_SNP_calling/library_combinations/genome)
BCF_FILE=$(sed -n "${line_num}p" /home/tmjj24/scripts/Github/Thesis-Phylogeographic-Hetaerina/2_SNP_calling/library_combinations/library_name)

library_version=(/nobackup/tmjj24/ddRAD/Demultiplexed_seq_processing/SNP_libraries_SDC_manuscript/)

echo "Processing database $Library_name using $genome"

cd $library_version/$Library_name/

##### Radomly sample one SNP per 1000bp window
echo '6. SNPS randomly thinned to one per 1000 bases'
bcftools +prune -n 1 -N rand -w 1000bp $BCF_FILE.all.snps.NOGTDP10.MEANGTDP10_200.Q60.SAMP0.8.MAF2.bcf -Ob -o $BCF_FILE.all.snps.NOGTDP10.MEANGTDP10_200.Q60.SAMP0.8.MAF2.rand1000.bcf
bcftools view -H $BCF_FILE.all.snps.NOGTDP10.MEANGTDP10_200.Q60.SAMP0.8.MAF2.rand1000.bcf | grep -v -c '^#'
bcftools view -O z $BCF_FILE.all.snps.NOGTDP10.MEANGTDP10_200.Q60.SAMP0.8.MAF2.rand1000.bcf > $BCF_FILE.all.snps.NOGTDP10.MEANGTDP10_200.Q60.SAMP0.8.MAF2.rand1000.vcf.gz

Rscript /home/tmjj24/scripts/Github/Thesis-Phylogeographic-Hetaerina/2_SNP_calling/7_SNP_filtering_vcfR.R $Library_name $library_version

## Get the most highest quality samples
cd $library_version/$Library_name/

bcftools stats -s - $Library_name.all.snps.NOGTDP10.MEANGTDP10_200.Q60.SAMP0.8.MAF2.rand1000.vcf.gz > ${Library_name}_bcfstats_snps.txt

plot-vcfstats -p bcfstats ${Library_name}_bcfstats_snps.txt

