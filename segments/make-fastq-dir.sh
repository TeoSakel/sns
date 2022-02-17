#!/bin/bash -e

# Check if fastq directory exist and has the right format otherwise create it

# script filename
script_path="${BASH_SOURCE[0]}"
script_name=$(basename "$script_path")
segment_name=${script_name/%.sh/}
echo -e "\n ========== SEGMENT: $segment_name ========== \n" >&2

# check for correct number of arguments
if [ $# -ne 3 ] ; then
	echo -e "\n $script_name ERROR: WRONG NUMBER OF ARGUMENTS SUPPLIED \n" >&2
	echo -e "\n USAGE: $script_name proj_dir sample_csv fastq_raw \n" >&2
	if [ $# -gt 0 ] ; then echo -e "\n ARGS: $* \n" >&2 ; fi
	exit 1
fi

# arguments
proj_dir=$(readlink -f "$1")
sample_csv=$2
outdir=$3

# functions
link_sample () {
    basedir=$1
    line=$2
    IFS=',' read -r -a FASTQ <<< "$line"
    SAMPLE_DIR="$basedir"/"${FASTQ[0]}"
    mkdir -p "$SAMPLE_DIR"
    for R in "${FASTQ[@]:1}"; do
        ln -s "$R" "$SAMPLE_DIR"/
    done
}

check_sample () {
    basedir=$1
    line=$2
    IFS=',' read -r -a FASTQ <<< "$line"

    # check if directory exists
    SAMPLE_DIR="$basedir"/"${FASTQ[0]}"
    if [[ ! -d "$SAMPLE_DIR" ]]; then
        echo -e "\n ERROR: DIR ${SAMPLE_DIR} DOES NOT EXIST \n" >&2
        echo -e " ${basedir} MUST BE ORGANIZED LIKE: ${SAMPLE_DIR}/[fastqs] \n" >&2
        exit 1
    fi

    # check if content is correct
    DIRFILE=$(mktemp)
    FASTQFILE=$(mktemp)
    find -L "$SAMPLE_DIR" -type f -exec md5sum {} + | sort -k 1 | cut -d' ' -f1 > "$DIRFILE"
    md5sum "${FASTQ[@]:1}" | sort -k 1 | cut -d' ' -f1 > "$FASTQFILE"
    if ! diff -q "$DIRFILE" "$FASTQFILE" ; then
        echo -e "\n FASTQ FILES IN $SAMPLE_DIR DIFFER FROM THE FILES IN sample.fastq-raw.csv \n" >&2
        exit 1
    fi
    rm -f "$DIRFILE" "$FASTQFILE"

    return 0
}


#########################


Nsamples=$(wc -l < "$sample_csv")
Ndirs=$(ls -d "$outdir"/* 2> /dev/null | wc -l)

if [[ "$Ndirs" -gt 0 ]]; then
    # $outdir exists and is not empty
    if [[ $Ndirs -ne $Nsamples ]]; then
        # check if number of samples match
        echo -e "\n ERROR: NUMBERS OF SAMPLES in samples.fastq-raw.csv DOES NOT MUCH DIRS IN ${outdir} \n"
        exit 1
    fi
    # check directory content
    while IFS= read -r line; do
        check_sample "$outdir" "$line";
    done < samples.fastq-raw.csv
else
    # $outdir does not exist or is empty
    while IFS= read -r line; do
        link_sample "$outdir" "$line";
    done < samples.fastq-raw.csv
fi


#########################



# end
