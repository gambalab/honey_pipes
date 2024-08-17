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
    echo "This pipeline employs minimap2 for rapid and accurate alignment of long reads from Oxford Nanopore Technology."
    echo
    echo "Tailored for variant calling, it processes input reads in BAM or FASTQ format, with BAM strongly preferred."
    echo
    echo "To maintain precise allele frequency estimation, the pipeline strictly aligns simplex and duplex reads, excluding redundant duplex parent reads that can skew variant frequency calculations."
    echo
    echo "Since FASTQ format lacks read type information (simplex, duplex, or parent), distinguishing these read types is only feasible with BAM input generated using the dorado duplex basecalling command."
    echo
    echo "Syntax: run_aln_long.sh [h|t|o|S|i|m|T|s|r|p|M|l]"
        echo "options:"
        echo "-h     Print this Help."
        echo "-t     Number of cpus to use."
        echo "-o     Output directory."
        echo "-S     Sample name."
        echo "-i     Path to the folder containing the unaligned BAM or FASTQ files."
        echo "-m     Optinal path to Temporary Folder: To optimize performance, consider specifying a path to an additional or faster HDD. This can significantly reduce overall input/output time."
        echo "-T     SM TAG to use in the final bam file. Default is the sample name."
        echo "-s     Save Stats on aligned reads and coverage. Default true."
        echo "-r     Path to reference genome"
        echo "-p     Minimap2 preset for indexing and mapping. Alias for the -x option in minimap2. [default: lr:hqae]. You can change it with lr:hq or map-ont or any other supported by minimap2."
        echo "-M     Total amount of memory to use for sorting reads. Default is 16GB. Higer amount will increase perfomances lowering I/O operation. A good value is 60GB."
        echo "-l     Library kit to use in the LB TAG of final bam file. Deafaul value is R10.4.1_LSK14"
        echo
}

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.
declare -i count=0
STAT="true"
TMP_STORAGE=""
INDIVIDUAL=""
M2_PRESET="lr:hqae"
MEM=16
LB_KIT="R10.4.1_LSK14"
while getopts ":hl:s:p:T:M:t:o:S:i:m:r:l:" option; do
   case $option in
      h) # display Help
         Help
         exit;;
      o)
         BAM_OUTPUT_FOLDER=${OPTARG}
         ((count++))
         ;;
      S)
         SAMPLE=${OPTARG}
         ((count++))
         ;;
      i)
         BAM_INPUT_FOLDER=${OPTARG}
         ((count++))
         ;;
      m)
         TMP_STORAGE=${OPTARG}
         ;;
      T)
         INDIVIDUAL=${OPTARG}
         ;;
      s)
         STAT=${OPTARG}
         ;;
      r)
         REF_GENOME=${OPTARG}
         ((count++))
         ;;
      t)
         THREADS=${OPTARG}
         ((count++))
         ;;
      p)
         M2_PRESET=${OPTARG}
         ;;
      M)
         MEM=${OPTARG}
         ;;
      l) 
         LB_KIT=${OPTARG}
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


if [ ! -d "${BAM_INPUT_FOLDER}" ]; then
  print_error "${BAM_INPUT_FOLDER} does not exist."
fi

if [ "${INDIVIDUAL}" == "" ]; then
    INDIVIDUAL=${SAMPLE}
fi


# START
#--------
BAM_OUTPUT_FOLDER="${BAM_OUTPUT_FOLDER}/${SAMPLE}"
mkdir -p ${BAM_OUTPUT_FOLDER}

if [ "${TMP_STORAGE}" == "" ]; then
    TMP_STORAGE=${BAM_OUTPUT_FOLDER}
else
    mkdir -p ${TMP_STORAGE}
fi

TMP_STORAGE=$(mktemp -d --tmpdir=${TMP_STORAGE})


# 1. Input files are BAMs aln only simplex and duplex reads
#-----------------------------------------------------------
print_info "Aln simplex and duplex reads from ${SAMPLE}.."
count=0
tmpdir_sort=$(mktemp -d --tmpdir=${TMP_STORAGE})
for BAM in ${BAM_INPUT_FOLDER}/*.bam; do
    f="$(basename -- ${BAM})"

    print_info "Aligning & Sorting ${f}..."
    ionice -c 3 samtools view -d dx:0 -d dx:1 ${BAM} | \
        samtools fastq -@ 2 - |
        minimap2 -t ${THREADS} -ax ${M2_PRESET} ${REF_GENOME} - | \
        samtools view --threads 2 -bh | \
        sambamba sort --nthreads ${THREADS} --tmpdir="${tmpdir_sort}" -m ${MEM}G -o "${TMP_STORAGE}/${f}.sorted.bam" /dev/stdin

    (( count++ ))
done
rm -rf "${tmpdir_sort}"

# 2. ALn fastq reads if presents
#---------------------------------------
print_info "Aln simplex and duplex reads from ${SAMPLE}.."
tmpdir_sort=$(mktemp -d --tmpdir=${TMP_STORAGE})
for FASTQ in ${BAM_INPUT_FOLDER}/*.gz; do
    f="$(basename -- ${FASTQ})"

    print_info "Aligning & Sorting ${f}..."
    ionice -c 3 minimap2 -t ${THREADS} -ax ${M2_PRESET} ${REF_GENOME} ${FASTQ} | \
        samtools view --threads 2 -bh | \
        sambamba sort --nthreads ${THREADS} --tmpdir="${tmpdir_sort}" -m ${MEM}G -o "${TMP_STORAGE}/${f}.sorted.bam" /dev/stdin

    (( count++ ))
done
rm -rf "${tmpdir_sort}"

# Check if something was processed
if [[ ${count} == 0 ]]; then
   print_error "No bam or fastQ files found!"
   exit
fi


# 3. Merge Files & Add all TAGS
# -----------------
if [ ${count} -gt 1 ]; then
    print_info "Merging and Tagging ${SAMPLE}..."
    sambamba merge --nthreads ${THREADS} -p /dev/stdout ${TMP_STORAGE}/*.bam | \
        samtools addreplacerg -@ ${THREADS} -w -r ID:${SAMPLE} -r SM:${INDIVIDUAL} -r LB:${LB_KIT} -r PL:ONT -O BAM \
            -o "${BAM_OUTPUT_FOLDER}/${INDIVIDUAL}.sorted.uniq.bam" -
else
    print_info "Adding tags ${SAMPLE}..."
    samtools addreplacerg -@ ${THREADS} -w -r ID:${SAMPLE} -r SM:${INDIVIDUAL} -r LB:${LB_KIT} -r PL:ONT -O BAM \
            -o "${BAM_OUTPUT_FOLDER}/${INDIVIDUAL}.sorted.uniq.bam" "${TMP_STORAGE}/${f}.sorted.bam"
fi

rm ${TMP_STORAGE}/*.bam
rm ${TMP_STORAGE}/*.bai

print_info "Indexing ..."
sambamba index  --nthreads ${THREADS} -p "${BAM_OUTPUT_FOLDER}/${INDIVIDUAL}.sorted.uniq.bam"

if [ "${STAT}" == "true" ]; then
    print_info "Computing coverage stats ${INDIVIDUAL}..."
    samtools coverage "${BAM_OUTPUT_FOLDER}/${INDIVIDUAL}.sorted.uniq.bam" > "${BAM_OUTPUT_FOLDER}/${INDIVIDUAL}.sorted.uniq.bam.cov.txt"

    print_info "Computing aln stats ${INDIVIDUAL}..."
    sambamba flagstat --nthreads ${THREADS} -p "${BAM_OUTPUT_FOLDER}/${INDIVIDUAL}.sorted.uniq.bam" > "${BAM_OUTPUT_FOLDER}/${INDIVIDUAL}.sorted.uniq.bam.stat.txt"
fi

rm -rf ${TMP_STORAGE}