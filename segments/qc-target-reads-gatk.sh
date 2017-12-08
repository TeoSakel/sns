#!/bin/bash


# GATK on-target coverage (capture efficiency)


# script filename
script_name=$(basename "${BASH_SOURCE[0]}")
segment_name=${script_name/%.sh/}
echo -e "\n ========== SEGMENT: $segment_name ========== \n" >&2

# check for correct number of arguments
if [ ! $# == 4 ] ; then
	echo -e "\n $script_name ERROR: WRONG NUMBER OF ARGUMENTS SUPPLIED \n" >&2
	echo -e "\n USAGE: $script_name project_dir sample_name threads BAM \n" >&2
	exit 1
fi

# arguments
proj_dir=$1
sample=$2
threads=$3
bam=$4


#########################


# check that inputs exist

if [ ! -d "$proj_dir" ] ; then
	echo -e "\n $script_name ERROR: PROJ DIR $proj_dir DOES NOT EXIST \n" >&2
	exit 1
fi

if [ ! -s "$bam" ] ; then
	echo -e "\n $script_name ERROR: BAM $bam DOES NOT EXIST \n" >&2
	exit 1
fi

code_dir=$(dirname "$(dirname "${BASH_SOURCE[0]}")")

ref_fasta=$(bash ${code_dir}/scripts/get-set-setting.sh "${proj_dir}/settings.txt" REF-FASTA);

if [ ! -s "$ref_fasta" ] ; then
	echo -e "\n $script_name ERROR: FASTA $ref_fasta DOES NOT EXIST \n" >&2
	exit 1
fi

ref_dict=$(bash ${code_dir}/scripts/get-set-setting.sh "${proj_dir}/settings.txt" REF-DICT);

if [ ! -s "$ref_dict" ] ; then
	echo -e "\n $script_name ERROR: DICT $ref_dict DOES NOT EXIST \n" >&2
	exit 1
fi

found_bed=$(find $proj_dir -maxdepth 1 -type f -iname "*.bed" | grep -v "probes" | sort | head -1)
bed=$(bash ${code_dir}/scripts/get-set-setting.sh "${proj_dir}/settings.txt" EXP-TARGETS-BED $found_bed);

if [ ! -s "$bed" ] ; then
	echo -e "\n $script_name ERROR: BED $bed DOES NOT EXIST \n" >&2
	exit 1
fi


#########################


# settings and files

summary_dir="${proj_dir}/summary"
mkdir -p "$summary_dir"
summary_csv="${summary_dir}/${sample}.${segment_name}.csv"

cov_dir="${proj_dir}/QC-target-reads"
mkdir -p "$cov_dir"
out_prefix="${cov_dir}/${sample}"
out_prefix_genome="${out_prefix}.genome"
out_prefix_pad500="${out_prefix}.pad500"
out_prefix_pad100="${out_prefix}.pad100"
out_prefix_bed="${out_prefix}.bed"

# unload all loaded modulefiles
module purge
module load local


#########################


# exit if output exits already

if [ -s "${out_prefix_genome}.sample_summary" ] ; then
	echo -e "\n $script_name SKIP SAMPLE $sample \n" >&2
	exit 1
fi


#########################


# GATK settings

module load java/1.8

# command
gatk_jar="/ifs/home/id460/software/GenomeAnalysisTK/GenomeAnalysisTK-3.8-0/GenomeAnalysisTK.jar"
gatk_cmd="java -Xms16G -Xmx16G -jar $gatk_jar"

gatk_omit_arg="--omitIntervalStatistics --omitLocusTable --omitDepthOutputAtEachBase"
gatk_cutoff_arg="-ct 10 -ct 100 -mbq 20 -mmq 20"
gatk_ref_arg="--reference_sequence $ref_fasta"

# error log (blank for troubleshooting)
gatk_log_arg="--logging_level ERROR"

gatk_doc_args="-nt $threads $gatk_log_arg $gatk_omit_arg $gatk_cutoff_arg $gatk_ref_arg"
gatk_doc_cmd="$gatk_cmd -T DepthOfCoverage -dt NONE -rf BadCigar $gatk_doc_args"

if [ ! -s "$gatk_jar" ] ; then
	echo -e "\n $script_name ERROR: GATK $gatk_jar DOES NOT EXIST \n" >&2
	exit 1
fi


#########################


# on-target coverage

echo " * GATK: $(readlink -f $gatk_jar) "
echo " * GATK version: $($gatk_cmd --version) "
echo " * BAM IN: $bam "
echo " * OUT PREFIX: $out_prefix_genome "
echo " * OUT PREFIX: $out_prefix_pad500 "
echo " * OUT PREFIX: $out_prefix_pad100 "
echo " * OUT PREFIX: $out_prefix_bed "

# genome-wide coverage
gatk_doc_genome_cmd="
$gatk_doc_cmd \
--input_file $bam \
--outputFormat csv \
--out $out_prefix_genome
"
echo "CMD: $gatk_doc_genome_cmd"
$gatk_doc_genome_cmd

# bed +/- 500bp coverage
gatk_doc_pad500_cmd="
$gatk_doc_cmd \
--intervals $bed \
--interval_padding 500 \
--input_file $bam \
--outputFormat csv \
--out $out_prefix_pad500
"
echo "CMD: $gatk_doc_pad500_cmd"
$gatk_doc_pad500_cmd

# bed +/- 100bp coverage
gatk_doc_pad100_cmd="
$gatk_doc_cmd \
--intervals $bed \
--interval_padding 100 \
--input_file $bam \
--outputFormat csv \
--out $out_prefix_pad100
"
echo "CMD: $gatk_doc_pad100_cmd"
$gatk_doc_pad100_cmd

# bed coverage
gatk_doc_bed_cmd="
$gatk_doc_cmd \
--intervals $bed \
--input_file $bam \
--outputFormat csv \
--out $out_prefix_bed
"
echo "CMD: $gatk_doc_bed_cmd"
$gatk_doc_bed_cmd


#########################


# check that output generated

if [ ! -s "${out_prefix_genome}.sample_summary" ] ; then
	echo -e "\n $script_name ERROR: sample_summary ${out_prefix_genome}.sample_summary NOT GENERATED \n" >&2
	exit 1
fi


#########################


# generate summary

total_genome=$(cat ${out_prefix_genome}.sample_summary | grep -v "^sample_id," | grep -v "^Total," | cut -d ',' -f 2)
echo "genome total coverage: $total_genome"

total_pad500=$(cat ${out_prefix_pad500}.sample_summary | grep -v "^sample_id," | grep -v "^Total," | cut -d ',' -f 2)
echo "bed +/- 500bp total coverage: $total_pad500"
pct_pad500=$(echo "(${total_pad500}/${total_genome})*100" | bc -l | cut -c 1-4)
pct_pad500="${pct_pad500}%"
echo "bed +/- 500bp %: $pct_pad500"

total_pad100=$(cat ${out_prefix_pad100}.sample_summary | grep -v "^sample_id," | grep -v "^Total," | cut -d ',' -f 2)
echo "bed +/- 100bp total coverage: $total_pad100"
pct_pad100=$(echo "(${total_pad100}/${total_genome})*100" | bc -l | cut -c 1-4)
pct_pad100="${pct_pad100}%"
echo "bed +/- 100bp %: $pct_pad100"

total_bed=$(cat ${out_prefix_bed}.sample_summary | grep -v "^sample_id," | grep -v "^Total," | cut -d ',' -f 2)
echo "bed total coverage: $total_bed"
pct_bed=$(echo "(${total_bed}/${total_genome})*100" | bc -l | cut -c 1-4)
pct_bed="${pct_bed}%"
echo "bed %: $pct_bed"

# header for summary file
echo "#SAMPLE,ON-TARGET,ON-TARGET 100BP PAD,ON-TARGET 500BP PAD" > "$summary_csv"

# summarize log file
echo "${sample},${pct_bed},${pct_pad100},${pct_pad500}" >> "$summary_csv"

sleep 30

# combine all sample summaries
cat ${summary_dir}/*.${segment_name}.csv | LC_ALL=C sort -t ',' -k1,1 | uniq > "${proj_dir}/summary.${segment_name}.csv"


#########################



# end
