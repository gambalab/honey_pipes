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
    echo "This pipeline convert pod5 files into fastQ using dorado duplex sup model. Output fastQ are trimmed by default using dorado trim."
    echo
    echo "It does not require internet since models have been packaged into this singularity image."
    echo
    echo "Output folder will contain a folder named pod5_by_channel containing the pod5 files."
    echo "Syntax: run_dorado_duplex.sh [h|i|o|t]"
        echo "options:"
        echo "-h     Print this Help."
        echo "-i     Path to the folder containing the pod5 files"
        echo "-o     Output directory."
        echo "-s     Sample name."
        echo "-T     FastQ trimming. Default is true."
        echo "-C     Optional cuda device to pass to dorado, e.g. cuda:0,1"
        echo
}

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.
CUDA_D=""
while getopts ":h:t:i:o:s:" option; do
   case $option in
      h) # display Help
         Help
         exit;;
      t)
         TRIMMING=${OPTARG}
         ;;
      i)
         POD5_FOLDER=${OPTARG}
         ((count++))
         ;;
      o)
         FASTQ_FOLDER=${OPTARG}
         ((count++))
         ;;
      s)
         SAMPLE=${OPTARG}
         ((count++))
         ;;
      c) 
         CUDA_D=${OPTARG}
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
elif [[ ${count} -lt 3 ]]; then
      print_error "Missing some input arguments, please see the help (-h)"
      exit
fi

if [ "${CUDA_D}" != "" ]; then
   CUDA_D="--device ${CUDA_D}"
fi

echo "Sample ${i}"
dorado duplex sup ${CUDA_D} ${POD5_FOLDER} | dorado trim -t 4 > ${FASTQ_FOLDER}/${SAMPLE}_trimmed.bam

