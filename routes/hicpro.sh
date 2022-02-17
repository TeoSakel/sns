#!/bin/bash -e


##
## HiC alignment using HiC Pro
##


# script filename
script_path="${BASH_SOURCE[0]}"
script_name=$(basename "$script_path")
route_name=${script_name/%.sh/}
echo -e "\n ========== ROUTE: $route_name ========== \n" >&2

# check for correct number of arguments
if [ ! $# == 1 ] ; then
	echo -e "\n $script_name ERROR: WRONG NUMBER OF ARGUMENTS SUPPLIED \n" >&2
	echo -e "\n USAGE: $script_name project_dir \n" >&2
	exit 1
fi

# standard comparison route arguments
proj_dir=$(readlink -f "$1")

# additional settings
code_dir=$(dirname $(dirname "$script_path"))

# display settings
echo
echo " * proj_dir: $proj_dir "
echo " * code_dir: $code_dir "
echo


#########################


# check that inputs exist

if [ ! -d "$proj_dir" ] ; then
	echo -e "\n $script_name ERROR: DIR $proj_dir DOES NOT EXIST \n" >&2
	exit 1
fi

settings="$proj_dir"/settings.txt

sample_csv="$proj_dir"/samples.fastq-raw.csv
if [ ! -f "$sample_csv" ]; then
	echo -e "\n $script_name ERROR: FILE $sample_csv DOES NOT EXIST \n" >&2
	exit 1
fi


#########################


# segments
segment_dir="$code_dir"/segments
script_dir="$code_dir"/scripts

# check if FASTQ directory has the right structure
segment_fastq_dir="make-fastq-dir"
fastq_raw="$proj_dir"/FASTQ_RAW
bash_cmd="bash ${segment_dir}/${segment_fastq_dir}.sh ${proj_dir} ${sample_csv} ${fastq_raw}"
($bash_cmd)

# generate config file
segment_hicpro_config="config-hicpro"
config_file=$("$script_dir"/get-set-setting.sh "$settings" HiC_Pro-CONFIG 2> /dev/null || \
              "$script_dir"/get-set-setting.sh "$settings" HiC_Pro-CONFIG "$proj_dir"/config_hicpro.txt)
if [ ! -f "${config_file}" ]; then
    echo -e "\n ERROR: CONFIG FILE $config_file DOES NOT EXIST. GENERATING TEMPLATE..." >& 2
    bash_cmd="bash ${segment_dir}/${segment_hicpro_config}.sh ${proj_dir} ${config_file}"
    ($bash_cmd)
    echo -e "\n EDIT $config_file AND RERUN \n" >& 2
    exit 2
fi

# align using HiC Pro
segment_align_hicpro="align-hicpro"
bash_cmd="bash ${segment_dir}/${segment_align_hicpro}.sh ${proj_dir} ${fastq_raw} ${config_file} "$proj_dir"/HiC-Pro_align"
($bash_cmd)


#########################

date


# end
