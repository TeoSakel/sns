#!/bin/bash


##
## ATAC-seq using Bowtie 2
##


# script filename
script_path="${BASH_SOURCE[0]}"
script_name=$(basename "$script_path")
route_name=${script_name/%.sh/}
echo -e "\n ========== ROUTE: $route_name ========== \n" >&2

# check for correct number of arguments
if [ ! $# == 2 ] ; then
	echo -e "\n $script_name ERROR: WRONG NUMBER OF ARGUMENTS SUPPLIED \n" >&2
	echo -e "\n USAGE: $script_name project_dir sample_name \n" >&2
	exit 1
fi

# standard route arguments
proj_dir=$(readlink -f "$1")
sample=$2

# additional settings
threads=$NSLOTS
code_dir=$(dirname $(dirname "$script_path"))
qsub_dir="${proj_dir}/logs-qsub"

# display settings
echo " * proj_dir: $proj_dir "
echo " * sample: $sample "
echo " * code_dir: $code_dir "
echo " * qsub_dir: $qsub_dir "
echo " * threads: $threads "


#########################


# delete empty qsub .po files
rm -f ${qsub_dir}/sns.*.po*


#########################


# segments

# rename and/or merge raw input FASTQs
segment_fastq_clean="fastq-clean"
fastq_R1=$(grep -s -m 1 "^${sample}," "${proj_dir}/samples.${segment_fastq_clean}.csv" | cut -d ',' -f 2)
fastq_R2=$(grep -s -m 1 "^${sample}," "${proj_dir}/samples.${segment_fastq_clean}.csv" | cut -d ',' -f 3)
if [ -z "$fastq_R1" ] ; then
	bash_cmd="bash ${code_dir}/segments/${segment_fastq_clean}.sh $proj_dir $sample"
	($bash_cmd)
	fastq_R1=$(grep -m 1 "^${sample}," "${proj_dir}/samples.${segment_fastq_clean}.csv" | cut -d ',' -f 2)
	fastq_R2=$(grep -m 1 "^${sample}," "${proj_dir}/samples.${segment_fastq_clean}.csv" | cut -d ',' -f 3)
fi

# if FASTQ is not set, there was a problem
if [ -z "$fastq_R1" ] ; then
	echo -e "\n $script_name ERROR: SEGMENT $segment_fastq_clean DID NOT FINISH \n" >&2
	exit 1
fi

# run alignment
segment_align="align-bowtie2-atac"
bam_bt2=$(grep -s -m 1 "^${sample}," "${proj_dir}/samples.${segment_align}.csv" | cut -d ',' -f 2)
if [ -z "$bam_bt2" ] ; then
	bash_cmd="bash ${code_dir}/segments/${segment_align}.sh $proj_dir $sample $threads $fastq_R1 $fastq_R2"
	($bash_cmd)
	bam_bt2=$(grep -m 1 "^${sample}," "${proj_dir}/samples.${segment_align}.csv" | cut -d ',' -f 2)
fi

# if BAM is not set, there was a problem
if [ -z "$bam_bt2" ] ; then
	echo -e "\n $script_name ERROR: SEGMENT $segment_align DID NOT FINISH \n" >&2
	exit 1
fi

# remove duplicates
segment_dedup="bam-dedup-sambamba"
bam_dd=$(grep -s -m 1 "^${sample}," "${proj_dir}/samples.${segment_dedup}.csv" | cut -d ',' -f 2)
if [ -z "$bam_dd" ] ; then
	bash_cmd="bash ${code_dir}/segments/${segment_dedup}.sh $proj_dir $sample $threads $bam_bt2"
	($bash_cmd)
	bam_dd=$(grep -m 1 "^${sample}," "${proj_dir}/samples.${segment_dedup}.csv" | cut -d ',' -f 2)
fi

# if BAM is not set, there was a problem
if [ -z "$bam_dd" ] ; then
	echo -e "\n $script_name ERROR: SEGMENT $segment_dedup DID NOT FINISH \n" >&2
	exit 1
fi

# generate BigWig (deeptools)
segment_bigwig_deeptools="bigwig-deeptools"
bash_cmd="bash ${code_dir}/segments/${segment_bigwig_deeptools}.sh $proj_dir $sample 4 $bam_dd"
qsub_cmd="qsub -N sns.${segment_bigwig_deeptools}.${sample} -M ${USER}@nyumc.org -m a -j y -cwd -pe threaded 4 -b y ${bash_cmd}"
$qsub_cmd

# fragment size distribution
segment_qc_frag_size="qc-fragment-sizes"
bash_cmd="bash ${code_dir}/segments/${segment_qc_frag_size}.sh $proj_dir $sample $bam_dd"
($bash_cmd)

# call peaks
segment_peaks="peaks-macs-atac"
bash_cmd="bash ${code_dir}/segments/${segment_peaks}.sh $proj_dir $sample $bam_dd 0.05"
($bash_cmd)
bash_cmd="bash ${code_dir}/segments/${segment_peaks}.sh $proj_dir $sample $bam_dd 0.20"
($bash_cmd)

# call nucleosomes
segment_nuc="nucleosomes-nucleoatac"
bash_cmd="bash ${code_dir}/segments/${segment_nuc}.sh $proj_dir $sample $threads $bam_dd"
($bash_cmd)


#########################


# combine summary from each step

sleep 30

summary_csv="${proj_dir}/summary-combined.${route_name}.csv"

bash_cmd="
bash ${code_dir}/scripts/join-many.sh , X \
${proj_dir}/summary.${segment_fastq_clean}.csv \
${proj_dir}/summary.${segment_align}.csv \
${proj_dir}/summary.${segment_dedup}.csv \
${proj_dir}/summary.${segment_peaks}-q-0.05.csv \
> $summary_csv
"
(eval $bash_cmd)


#########################


# delete empty qsub .po files
rm -f ${qsub_dir}/sns.*.po*


#########################


date



# end
