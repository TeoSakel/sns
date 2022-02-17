#!/bin/bash -e

# script filename
script_path="${BASH_SOURCE[0]}"
script_name=$(basename "$script_path")
segment_name=${script_name/%.sh/}
echo -e "\n ========== SEGMENT: $segment_name ========== \n" >&2

# check for correct number of arguments
if [ $# -ne 4 ] ; then
	echo -e "\n $script_name ERROR: WRONG NUMBER OF ARGUMENTS SUPPLIED \n" >&2
	echo -e "\n USAGE: $script_name proj_dir fastq_raw config_file outdir \n" >&2
	if [ $# -gt 0 ] ; then echo -e "\n ARGS: $* \n" >&2 ; fi
	exit 1
fi

# arguments
proj_dir=$(readlink -f "$1")
INDIR=$2
CONFIG_FILE=$3
OUTDIR=$4

code_dir=$(dirname "$(dirname "$script_path")")
BOWTIE2_IDX_PATH=$("$code_dir"/scripts/get-set-setting.sh settings.txt REF-BOWTIE2)

module purge
module add default-environment


#########################

module load hic-pro

# check that inputs exists

if [ ! -d "$INDIR" ]; then
	echo -e "\n $script_name ERROR: DIR $INDIR DOES NOT EXIST \n" >&2
	exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
	echo -e "\n $script_name ERROR: FILE $CONFIG_FILE DOES NOT EXIST \n" >&2
	exit 1
fi

# Run HiC-pro for parallel
HiC-Pro -i "$INDIR" -o "$OUTDIR" -c "$CONFIG_FILE" -p

# adjust config file
mv "$OUTDIR"/"$(basename "$CONFIG_FILE")" "$OUTDIR"/config.txt
CONFIG_FILE="$OUTDIR"/config.txt

# work around for HiC Pro index naming convention
REF_GENOME=$(grep REFERENCE_GENOME "$CONFIG_FILE" | sed 's/REFERENCE_GENOME = //')
IDX_PREFIX=$(basename "$BOWTIE2_IDX_PATH")
if [[ "$IDX_PREFIX" != "$REF_GENOME" ]]; then
    mkdir "$OUTDIR"/bowtie2_idx
    for bt2 in "$BOWTIE2_IDX_PATH"/"$IDX_PREFIX"*; do
        ln -s "$bt2" "$OUTDIR"/bowtie2_idx/"$REF_GENOME"."${bt2#*.}"
    done

    BOWTIE2_IDX_PATH=$(readlink -f "$OUTDIR"/bowtie2_idx)
    sed -i "/^BOWTIE2_IDX_PATH/c\\BOWTIE2_IDX_PATH = $BOWTIE2_IDX_PATH" "$CONFIG_FILE"
fi

# clean up sbatch files
JOB_NAME=$(grep JOB_NAME "$CONFIG_FILE" | sed 's/JOB_NAME = //')
STEP1=HiCPro_step1_"$JOB_NAME".sh
STEP2=HiCPro_step2_"$JOB_NAME".sh

clean_step () {
    STEP="$1"
    sed -i "s,CONFIG_FILE=\S*,CONFIG_FILE=config.txt," "$STEP"
    sed -i "/mail-user= *$/d" "$STEP"
}

clean_step "$OUTDIR"/"$STEP1"
clean_step "$OUTDIR"/"$STEP2"

(cd "$OUTDIR"; jid1=$(sbatch --parsable "$STEP1"); sbatch -Q --dependency=afterok:"$jid1" "$STEP2")
