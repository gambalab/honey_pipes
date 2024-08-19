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
    echo "The pipeline leverages the pod5 package to efficiently divide fast5 or pod5 files into channel-specific pod5 formats."
    echo "If the input folder contains fast5 files these are first converted into POD5 and then splitted."
    echo
    echo "This optimization is expected to significantly improve basecalling performance."
    echo
    echo "Output folder will contain a folder named pod5_by_channel containing the pod5 files."
    echo "Syntax: run_dragen.sh [h|i|o|t]"
        echo "options:"
        echo "-h     Print this Help."
        echo "-t     Number of cpus to use."
        echo "-i     Path to the folder containing the fast5 files"
        echo "-o     Output directory."
        echo "-s     Sample name."
        echo
}

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.
while getopts ":ht:i:o:s:" option; do
   case $option in
      h) # display Help
         Help
         exit;;
      t)
         cpus=${OPTARG}
         ((count++))
         ;;
      i)
         FAST5_FOLDER=${OPTARG}
         ((count++))
         ;;
      o)
         POD5=${OPTARG}
         ((count++))
         ;;
      s)
         SAMPLE=${OPTARG}
         ((count++))
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
elif [[ ${count} -lt 4 ]]; then
      print_error "Missing some input arguments, please see the help (-h)"
      exit
fi


POD5="${POD5}/${SAMPLE}"
mkdir -p ${POD5}

myarray=(`find ${FAST5_FOLDER} -maxdepth 1 -name "*.fast5"`)
if [ ${#myarray[@]} -gt 0 ]; then 
    ast5=true 
else 
    fast5=false
fi

if [ ${fast5} ]; then
   print_info "Detected fast5 files.."
   print_info "Start Conversion fast5 to pod5 for ${SAMPLE} .."
   ionice -c 3 pod5 convert fast5 --force-overwrite --t ${cpus} -o ${POD5} ${FAST5_FOLDER}
fi

myarray=(`find ${FAST5_FOLDER} -maxdepth 1 -name "*.pod5"`)
if [ ${#myarray[@]} -gt 0 ]; then 
    pod5=true 
else 
    pod5=false
fi


if [ ${pod5} ]; then
   print_info "Compute channel summary ..."
   ionice -c 3 pod5 view ${POD5} --force-overwrite -t ${cpus} --include "read_id, channel" --output ${POD5}/channel.summary.tsv

   print_info "Start Channel Splitting ..."
   ionice -c 3 pod5 subset ${POD5} --force-overwrite -t ${cpus} --summary ${POD5}/channel.summary.tsv --columns channel --output ${POD5}/pod5_by_channel/

   if [ ${fast5} == "true" ]; then 
      rm ${POD5}/*.pod5
   fi
   print_info "Finished!"
else
   print_error "No FAST5 or POD5 found in the input directory!"
fi
