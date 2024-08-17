# HONEY PIPES
A set high-performance, easy-to-use, open source pipelines for processing Illumina and Oxford Nanopore reads.
If you use this repository please cite our manuscript on Bioxriv available at following address **www_URL_coming_soon.com**.

## Features
This repository provides pipelines used in our recent publication available on BioRxiv at **www_URL_coming_soon.com** for processing raw Oxford Nanopore Technology (ONT) and Illumina sequencing data from three key consortia: Genome in a Bottle (GIAB), Human Pangenome Reference Consortium (HPRC), and Oxford Nanopore Technologies Open Data (ONT OD).

* **Harmonized data**: The processed data is now publicly available for the scientific community at **www_URL_coming_soon.com**.

* **Hybrid DeepVariant training**: This data was then used to train a novel DeepVariant model specifically designed for identifying variants from combined short-read and long-read sequencing data (hybrid sequencing). The resulting Honey DeepVariant tool for variant calling in hybrid sequencing data is available on GitHub: https://github.com/gambalab/honey_deepvariant

## Honey Pipes Overview
All pipelines are packaged into a single Singularity container named honey_pipes. This container includes the Dorado v0.7.3 base caller (https://github.com/nanoporetech/dorado) and all necessary models for base calling raw Oxford Nanopore Technology (ONT) data. A slim version of honey_pipes is also available, excluding Nvidia support and Dorado for users who don't require it or prefer to use their own version. Honey pipes image also incorporates some useful tools such as **bcftools**, **samtools**, **tabix**, **sambamba**, **bbmap**, **pod5**, **dragen-os**, and **minimap2** for added convenience.

## Installation of honey pipes package
To install the honey pipes Docker/Singularity image, run the following commands:

```bash
# 1. Install with Singularity and test it
singularity pull docker://gambalab/honey_pipe:1.0.0

# 2. Install with Docker and test it
docker pull gambalab/honey_pipe:1.0.0
```

The slim version can be installed as following:
```bash
# 1. Install with Singularity and test it
singularity pull docker://gambalab/honey_pipe_slim:1.0.0

# 2. Install with Docker and test it
docker pull gambalab/honey_pipe_slim:1.0.0
```

## 1. Pipeline for Short Read Alignment with DragMap

**Description:** This pipeline utilizes the DragMap aligner (https://github.com/Illumina/DRAGMAP) for efficient alignment of short read data obtained from Illumina sequencing platforms. It offers optional pre- and post-processing steps to enhance alignment quality.
* **Input:** Raw FASTQ files.
* **Preprocessing** (optional): Adapter trimming using bbduk (https://github.com/kbaseapps/BBTools).
* **Alignment:** DragMap aligns the reads to a reference genome.
* **Postprocessing:** Samtools (https://github.com/samtools) removes potential PCR duplicates from the aligned reads.

The pipeline is coded in the ```run_aln_short.sh``` script and can be run in the following way:

```bash
# Let's define a honey_pipe_exec variable to excec the several commands 
HONEY_exec="singularity exec --bind /usr/lib/locale/ path/to/honey_pipe_1.0.0.sif"

# Let's see the help
${HONEY_exec} run_aln_short.sh -h
```
```
This pipeline employs DragMap for efficient read alignment, incorporating optional preprocessing and post-processing steps.

Key Steps:

  1. Optional Trimming: If enabled, reads are initially trimmed using the BBduk tool to remove low-quality bases and adaptors.
  2. Alignment: The trimmed or original reads are aligned to the reference genome using DragMap.
  3. Duplicate Marking and Removal: Samtools markdup is utilized to identify and remove potential PCR duplicates from the aligned reads.
  4. Output Organization: Results are organized into three distinct folders:
	 4.1 aln: Contains the final aligned BAM file.
	 4.2 fastq: Stores the trimmed FASTQ files if trimming was performed.
	 4.3 stat: Provides statistical information about trimming (if applicable) and alignment coverage.

This streamlined workflow ensures accurate and efficient read alignment, while the organized output facilitates downstream analysis.

Syntax: run_aln_short.sh [h|s|1|2|o|r|c|t]
options:
-h     Print this Help.
-c     Number of cpus to use.
-o     Output directory.
-s     Sample name.
-1     Path to the read1 FASTQ
-2     Path to the read2 FASTQ
-r     Path to the Dragmap reference folder.
-t     Trimming. Default false.
```

So a typical case of use will be something like this:

```bash
${HONEY_exec} \
    run_aln_short.sh \
   -c 32 \
   -o /path/to/output_folder \
   -s sample_name \
   -1 /path/to/fastQ_R1 \
   -2 /path/to/fastQ_R2 \
   -r /path/to/dragmap_idx_folder \
   -t "true"
```

Results file will be storend into ```/path/to/output_folder/sample_name/``` folder. In this folder will be contained 3 subfolder: (1) ```aln subfolder``` with aligned BAM file; (2) ```fastq subfolder``` with trimmed fastQ files if trimming was enabled and (3) ```stats subfolders``` with few stats if they were enabled.


**NOTE:** You can build DragMap index folder with the following command:

```bash
# Build hash table of a reference fasta file
${HONEY_exec} dragen-os \
    --build-hash-table true \
    --ht-reference /path/to/reference.fasta \
    --output-directory /path/to/dragmap_idx_folder
```

## 2. Pipeline for FAST5/POD5 to POD5 Split by Channel.
**Description:** This pipeline converts input FAST5/POD5 files into POD5 Split by Channel in order to optimize basecalling performance. Splitting POD5 files by channel can significantly improve performance, especially when working with large datasets or on systems with limited I/O capabilities. The pipeline supports parallel processing for faster conversion of large datasets.

Input: Folder with FAST5/POD5 files.
Processing: Uses the pod5 package to efficiently divide FAST5 files into channel-specific POD5 formats.
Output: Channel-specific POD5 files. 

The pipeline is coded in the ```run_split_pod5.sh``` script and can be run in the following way:
```bash
# Let's define a honey_pipe_exec variable to excec the several commands 
HONEY_exec="singularity exec --bind /usr/lib/locale/ path/to/honey_pipe_1.0.0.sif"

# Let's see the help
${HONEY_exec} run_split_pod5.sh -h
```
```
The pipeline leverages the pod5 package to efficiently divide fast5 or pod5 files into channel-specific pod5 formats. 
If the input folder contains fast5 files these are first converted into POD5 and then splitted.

This optimization is expected to significantly improve basecalling performance.

Output folder will contain a folder named pod5_by_channel containing the pod5 files.
Syntax: run_dragen.sh [h|i|o|t]
options:
-h     Print this Help.
-t     Number of cpus to use.
-i     Path to the folder containing the fast5/pod5 files
-o     Output directory.
-s     Sample name.
```

So a typical case of use will be something like this:
```bash
${HONEY_exec} \
    run_split_pod5.sh \
    -i /path/to/input/folder/with/fast5_or_pod5 \
    -o /path/to/output_folder \
    -s sample_name \
    -t 16
```

POD5 file will be storend into ```/path/to/output_folder/sample_name/pod5_by_channel/``` folder.

## 3. Pipeline for converting POD5 to ONT Long Reads (Not available in honey pipes slim)
**Description:** This pipeline converts POD5 files into long reads in BAM format using the dorado duplex sup command. The pipeline optionaly trims reads using dorado trim and selects the appropriate model for basecalling. The required models are included within the Singularity image, eliminating the need for internet connectivity.

* **Input:** Folder containing POD5 files.
* **Processing:** 
	* ```dorado duplex sup``` converts POD5 files into long reads.
	* (Optional) ```dorado trim``` trims the reads. Enabled by default.
	* The appropriate basecalling model is automatically selected by dorado.

* **Output**: BAM file containing long reads.

The pipeline is coded in the ```run_split_pod5.sh``` script and can be run in the following way:
```bash
# Let's define a honey_pipe_exec variable to excec the several commands
# Here we need to enable Nvidia Support since dorado requires it.
HONEY_exec="singularity exec --nv --bind /usr/lib/locale/ path/to/honey_pipe_1.0.0.sif"

# Let's see the help
${HONEY_exec} run_dorado_duplex.sh -h
```
```
This pipeline convert pod5 files into reads will be stored into a BAM using dorado duplex sup command.

Reads are trimmed by default using dorado trim.

It does not require internet since models have been packaged into this singularity image.

Output folder will contain a folder named pod5_by_channel containing the pod5 files.
Syntax: run_dorado_duplex.sh [h|i|o|t]
options:
-h     Print this Help.
-i     Path to the folder containing the pod5 files
-o     Output directory.
-s     Sample name.
-T     FastQ trimming. Default is true.
-C     Optional cuda device to pass to dorado, e.g. cuda:0,1
```

So a typical case of use will be something like this:
```bash
${HONEY_exec} \
    run_dorado_duplex.sh \
    -i /path/to/input/folder/with/pod5_by_channel \
    -o /path/to/output_folder \
    -s sample_name
```
BAM file will be storend into ```/path/to/output_folder/sample_name/sample_name_trimmed.bam```.

## 4. Pipeline for AlignmentONT Long Reads.
**Description:** This pipeline employs minimap2 for efficient and accurate alignment of long reads generated by Oxford Nanopore Technology. Primarily designed for variant calling, the pipeline accepts input reads in BAM or FASTQ format, with BAM strongly preferred due to its inclusion of additional read type information (e.g., simplex, duplex, or parent). To ensure precise allele frequency estimation, the pipeline strictly aligns simplex and duplex reads, excluding redundant duplex parent reads that can distort variant frequency calculations. Since FASTQ format lacks read type information, distinguishing between simplex, duplex, and parent reads is only possible with BAM input generated using the ```dorado duplex``` basecalling command.

* **Input:** A folder containing multiple BAM or FASTQ files with ONT long reads.

* **Processing:**
	* If BAM files are provided, the pipeline filters out redundant duplex parent reads.
	* Minimap2 aligns long reads to a reference genome, using the lr:hqae preset for indexing and mapping by default. This preset can be customized as needed.
	* (Optional) The pipeline computes statistics on coverage and the number of aligned reads.

* **Output:** A single BAM file containing aligned reads, along with optional statistics on coverage and aligned reads.

The pipeline is coded in the ```run_aln_long.sh``` script and can be run in the following way:
```bash
# Let's define a honey_pipe_exec variable to excec the several commands
HONEY_exec="singularity exec --bind /usr/lib/locale/ path/to/honey_pipe_1.0.0.sif"

# Let's see the help
${HONEY_exec} run_aln_long.sh -h
```
```
This pipeline employs minimap2 for rapid and accurate alignment of long reads from Oxford Nanopore Technology.

Tailored for variant calling, it processes input reads in BAM or FASTQ format, with BAM strongly preferred.

To maintain precise allele frequency estimation, the pipeline strictly aligns simplex and duplex reads, excluding redundant duplex parent reads that can skew variant frequency calculations.

Since FASTQ format lacks read type information (simplex, duplex, or parent), distinguishing these read types is only feasible with BAM input generated using the dorado duplex basecalling command.

Syntax: run_aln_long.sh [h|t|o|S|i|m|T|s|r|p|M|l]
options:
-h     Print this Help.
-t     Number of cpus to use.
-o     Output directory.
-S     Sample name.
-i     Path to the folder containing the unaligned BAM or FASTQ files.
-m     Optinal path to Temporary Folder: To optimize performance, consider specifying a path to an additional or faster HDD. This can significantly reduce overall input/output time.
-T     SM TAG to use in the final bam file. Default is the sample name.
-s     Save Stats on aligned reads and coverage. Default true.
-r     Path to reference genome
-p     Minimap2 preset for indexing and mapping. Alias for the -x option in minimap2. [default: lr:hqae]. You can change it with lr:hq or map-ont or any other supported by minimap2.
-M     Total amount of memory to use for sorting reads. Default is 16GB. Higer amount will increase perfomances lowering I/O operation. A good value is 60GB.
-l     Library kit to use in the LB TAG of final bam file. Deafaul value is R10.4.1_LSK14
```
So a typical case of use will be something like this:
```bash
#NOTE: by default the SM tag used is the sample name provided with -S
${HONEY_exec} \
    run_dorado_duplex.sh \
    -t 64 \
    -i /path/to/input/folder/with/unligned/bams \
    -o /path/to/output_folder \
    -S sample_name \
    -r /path/to/reference.fasta \
    -M 32 \
    -T SM_tag

```
Aligned and merged BAM file will be storend into ```/path/to/output_folder/sample_name/SM_tag.sorted.uniq.bam```.
