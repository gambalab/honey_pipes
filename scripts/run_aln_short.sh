#!/bin/bash

#############################################
# Color Definitions                         #
#############################################
# Reset
 Color_Off=$'\033[0m'       # Text Reset

 # Regular Colors
 Black=$'\033[0;30m'        # Black
 Red=$'\033[0;31m'          # Red
 Green=$'\033[0;32m'        # Green
 Yellow=$'\033[0;33m'       # Yellow
 Blue=$'\033[0;34m'         # Blue
 Purple=$'\033[0;35m'       # Purple
 Cyan=$'\033[0;36m'         # Cyan
 White=$'\033[0;37m'        # White

print_info(){
 dt=$(date '+%d/%m/%Y %H:%M:%S')
 echo "[${Cyan}${dt}${Color_Off}] [${Green}info${Color_Off}] ${1}"
}

print_error(){
 dt=$(date '+%d/%m/%Y %H:%M:%S')
 echo "[${Cyan}${dt}${Color_Off}] [${Red}error${Color_Off}] ${1}"
}

################################################################################
# Help                                                                         #
################################################################################
Help()
{
   # Display Help
	echo
	echo "This pipeline employs DragMap for efficient read alignment, incorporating optional preprocessing and post-processing steps."
	echo
	echo "Key Steps:"
	echo
	echo "  1. Optional Trimming: If enabled, reads are initially trimmed using the BBduk tool to remove low-quality bases and adaptors."
	echo "  2. Alignment: The trimmed or original reads are aligned to the reference genome using DragMap."
	echo "  3. Duplicate Marking and Removal: Samtools markdup is utilized to identify and remove potential PCR duplicates from the aligned reads."
	echo "  4. Output Organization: Results are organized into three distinct folders:"
	echo -e "\t 4.1 aln: Contains the final aligned BAM file."
	echo -e "\t 4.2 fastq: Stores the trimmed FASTQ files if trimming was performed."
	echo -e "\t 4.3 stat: Provides statistical information about trimming (if applicable) and alignment coverage."
	echo
	echo -e "This streamlined workflow ensures accurate and efficient read alignment, while the organized output facilitates downstream analysis."
	echo
	echo "Syntax: run_aln_short.sh [h|s|1|2|o|r|c|t]"
    	echo "options:"
    	echo "-h     Print this Help."
    	echo "-c     Number of cpus to use."
    	echo "-o     Output directory."
    	echo "-s     Sample name."
    	echo "-1     Path to the read1 FASTQ"
    	echo "-2     Path to the read2 FASTQ"
    	echo "-r     Path to the Dragmap reference folder."
    	echo "-t     Trimming. Default false."
    	echo
}

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.
declare -i count=0
trim="false"
while getopts ":ht:c:o:s:1:2:r:t:" option; do
   case $option in
      h) # display Help
         Help
         exit;;
      c)
         cpus=${OPTARG}
         ((count++))
         ;;
      o)
        OUT_DIR=${OPTARG}
        ((count++))
        ;;
      s)
         SAMPLE=${OPTARG}
         ((count++))
         ;;
      1)
         fastqR1=${OPTARG}
         ((count++))
         ;;
      2)
         fastqR2=${OPTARG}
         ((count++))
         ;;
      r)
         ref_genome_dragmap=${OPTARG}
         ((count++))
         ;;
      t)
         trim=${OPTARG}
         ;;
      :)
         print_error "Option -${OPTARG} requires an argument."
         exit 1
         ;;
     \?) # incorrect option
         print_error "Invalid Input option -${OPTARG}"
         exit;;
   esac
done

# Check the number of input args correspond
if [[ ${count} == 0 ]]; then
   print_error "No arguments in input, please see the help (-h)"
   exit
elif [[ ${count} -lt 5 ]]; then
      print_error "Missing some input arguments, please see the help (-h)"
      exit
fi

# check all required files exist
if [ ! -f ${fastqR1} ]; then
   print_error "FASTQ file 1 not found!!"
   exit 1
fi

if [ ! -f ${fastqR2} ]; then
   print_error "FASTQ file 2 not found!!"
   exit 1
fi

# Define Out Aln Folder
ALN_FOLDER=${OUT_DIR}/${SAMPLE}/aln
FASTQ_FOLDER=${OUT_DIR}/${SAMPLE}/fastq
STAT_FOLDER=${OUT_DIR}/${SAMPLE}/stats
mkdir -p ${ALN_FOLDER}
mkdir -p ${FASTQ_FOLDER}
mkdir -p ${STAT_FOLDER}


if [ "${trim}" != "false" ]; then
    adapters="/opt/conda/envs/bio/share/bbmap/resources/adapters.fa"

    print_info "BBDuk Soft Trimming..."
    bbdukParams="minlen=25 qtrim=rl trimq=20 ktrim=r k=23 mink=11 ref=${adapters} hdist=1 threads=${cpus} stats=${STAT_FOLDER}/trimming.stat.txt append=false"
    ionice -c 3 bbduk.sh in1=${fastqR1} in2=${fastqR2} out1=${FASTQ_FOLDER}/${SAMPLE}.trimmed.R1.fastq.gz out2=${FASTQ_FOLDER}/${SAMPLE}.trimmed.R2.fastq.gz ${bbdukParams}

    ## update fastq paths
    fastqR1="${FASTQ_FOLDER}/${SAMPLE}.trimmed.R1.fastq.gz"
    fastqR2="${FASTQ_FOLDER}/${SAMPLE}.trimmed.R2.fastq.gz"
    print_info "BBduk Finished!!"
fi

print_info "Aligning ..."
ionice -c 3 dragen-os \
    --preserve-map-align-order true \
    --num-threads ${cpus} \
    --RGID "${SAMPLE}" \
    --RGSM "${SAMPLE}" \
    --ref-dir ${ref_genome_dragmap} \
    --fastq-file1 ${fastqR1} --fastq-file2 ${fastqR2} | \
     ${DRAGMAP_exec} samtools view --threads 2 -bh -o "${ALN_FOLDER}/${SAMPLE}.unsorted.bam"

print_info "Fixmate Sort and rmdup ..."
ionice -c 3 samtools fixmate \
        --threads ${cpus} \
        -O bam \
        -rpcm "${ALN_FOLDER}/${SAMPLE}.unsorted.bam" - | \
        sambamba sort -t ${cpus} -m 16G -o /dev/stdout /dev/stdin | \
        samtools markdup --threads ${cpus} -rS - "${ALN_FOLDER}/${SAMPLE}.sorted.uniq.bam"

print_info "Indexing ..."
rm -rf "${ALN_FOLDER}/${SAMPLE}.unsorted.bam"
ionice -c 3 sambamba index -t ${cpus} "${ALN_FOLDER}/${SAMPLE}.sorted.uniq.bam"

print_info "Compute coverage.."
samtools coverage "${ALN_FOLDER}/${SAMPLE}.sorted.uniq.bam" > "${STAT_FOLDER}/${SAMPLE}.sorted.uniq.bam.cov.txt"
print_info "ALL FINISHED!!"

