#!/bin/bash

#SBATCH -c 1 
#SBATCH --mem=50G            # memory required, in units of k,M or G, up to 250G.
#SBATCH --gres=tmp:50G       # $TMPDIR space required on each compute node, up to 400G.
#SBATCH -t 48:00:00         # time limit in format dd-hh:mm:ss

# Specify the tasks to run:
#SBATCH --array=1-6  # Create 6 tasks, numbers 1 to 6
#SBATCH --output=slurm-%x.%j.out

# Commands to execute start here

#Modules
module load r/4.2.1
module load bioinformatics
module load bcftools

#Name of output SNP library

line_num=$(expr $SLURM_ARRAY_TASK_ID)
# line_num=$(expr 2)
echo "$line_num"

# Get library and genome names

Library_name=$(sed -n "${line_num}p" /home/tmjj24/scripts/Github/Thesis-Phylogeographic-Hetaerina/2_SNP_calling/library_combinations/library_name)
genome=$(sed -n "${line_num}p" /home/tmjj24/scripts/Github/Thesis-Phylogeographic-Hetaerina/2_SNP_calling/library_combinations/genome)

library_version=(/nobackup/tmjj24/ddRAD/Demultiplexed_seq_processing/SNP_libraries_SDC_manuscript/)

echo "Processing database $Library_name using $genome"

## Max number of samples to use from each lineage
select_N=(3)

## SNP library to use
SNP_file=($Library_name.all.snps.NOGTDP10.MEANGTDP10_200.Q60.SAMP0.8.MAF2.rand1000.biSNP0_20.noX.vcf.gz)

bcftools query -l $library_version/$Library_name/$Library_name.all.snps.NOGTDP10.MEANGTDP10_200.Q60.SAMP0.8.bcf > $library_version/$Library_name/samples_temp.txt

# Remove previous loci cals

# Get list of position for each SNP file
Rscript /home/tmjj24/scripts/Github/Thesis-Phylogeographic-Hetaerina/2_SNP_calling/8_RAD_loci_calling.R $Library_name $library_version $select_N

# index  bcf
bcftools index $library_version/$Library_name/$Library_name.all.snps.bcf

rm -r $library_version/$Library_name/fasta_files
mkdir $library_version/$Library_name/fasta_files

cat $library_version/$Library_name/${Library_name}_PHYLIP_subsample.txt | while read line; do
    #echo $library_version/$Library_name/fasta_files/$line.fa
    # Get sample name
    filename=$(basename "$line")
    # Remove extension
    filename=${filename:0:-11}
    echo $filename
    samtools faidx $genome -r $library_version/$Library_name/${Library_name}_RAD_posistions.txt | \
    bcftools consensus -s $line -e 'FORMAT/AD<5 & FORMAT/AD>200 & QUAL<50' -a "?" --iupac-codes -o $library_version/$Library_name/fasta_files/${filename}.fasta $library_version/$Library_name/$Library_name.all.snps.bcf 
done 

rm -r $library_version/$Library_name/RAD_loci
mkdir -p $library_version/$Library_name/RAD_loci

# Convert to phylip
Rscript /home/tmjj24/scripts/Github/Thesis-Phylogeographic-Hetaerina/2_SNP_calling/8_RAD_loci_calling_phylip.R $Library_name $library_version





