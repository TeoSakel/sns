#!/bin/bash -e

# Make HiC Pro config template

# script filename
script_path="${BASH_SOURCE[0]}"
script_name=$(basename "$script_path")
segment_name=${script_name/%.sh/}
echo -e "\n ========== SEGMENT: $segment_name ========== \n" >&2

# check for correct number of arguments
if [ $# -ne 2 ] ; then
	echo -e "\n $script_name ERROR: WRONG NUMBER OF ARGUMENTS SUPPLIED \n" >&2
	echo -e "\n USAGE: $script_name project_dir config_file \n" >&2
	if [ $# -gt 0 ] ; then echo -e "\n ARGS: $* \n" >&2 ; fi
	exit 1
fi

# arguments
proj_dir=$(readlink -f "$1")
config_file=$2

# hard-coded arguments
code_dir=$(dirname "$(dirname "$script_path")")
declare -A LIGATION_SITES
LIGATION_SITES[Arima]="GATCGATC,GANTGATC,GANTANTC,GATCANTC"
LIGATION_SITES[HindIII]="AAGCTAGCTT"

#########################


# get default parameters

GENOME_DIR=$("$code_dir"/scripts/get-set-setting.sh "$proj_dir"/settings.txt GENOME-DIR)
REF_GENOME=$(basename "$GENOME_DIR")
BOWTIE2_IDX_PATH=$("$code_dir"/scripts/get-set-setting.sh "$proj_dir"/settings.txt REF-BOWTIE2 | xargs dirname)
GENOME_SIZE=$("$code_dir"/scripts/get-set-setting.sh "$proj_dir"/settings.txt REF-CHROMSIZES)
ENZYME=$("$code_dir"/scripts/get-set-setting.sh "$proj_dir"/settings.txt ENZYME)
GENOME_FRAGMENT="$GENOME_DIR"/restriction-fragments/"$ENZYME".fragments.bed
LIGATION_SITE=${LIGATION_SITES["$ENZYME"]}

# write config_file

cat << EOF > "$config_file"
# Please change the variable settings below if necessary

#########################################################################
## Paths and Settings  - Do not edit !
#########################################################################

TMP_DIR = tmp
LOGS_DIR = logs
BOWTIE2_OUTPUT_DIR = bowtie_results
MAPC_OUTPUT = hic_results
RAW_DIR = rawdata

#######################################################################
## SYSTEM AND SCHEDULER - Start Editing Here !!
#######################################################################
N_CPU = 4
SORT_RAM = 2000M
LOGFILE = hicpro.log

JOB_NAME = sns-hicpro
JOB_MEM = 32G
JOB_WALLTIME = 6:00:00
JOB_QUEUE = cpu_short
JOB_MAIL = $(whoami)@nyulangone.org

#########################################################################
## Data
#########################################################################

PAIR1_EXT = _R1
PAIR2_EXT = _R2

#######################################################################
## Alignment options
#######################################################################

FORMAT = phred33
MIN_MAPQ = 10

BOWTIE2_IDX_PATH = $BOWTIE2_IDX_PATH
BOWTIE2_GLOBAL_OPTIONS = --very-sensitive -L 30 --score-min L,-0.6,-0.2 --end-to-end --reorder
BOWTIE2_LOCAL_OPTIONS =  --very-sensitive -L 20 --score-min L,-0.6,-0.2 --end-to-end --reorder

#######################################################################
## Annotation files
#######################################################################

REFERENCE_GENOME = ${REF_GENOME}
GENOME_SIZE = ${GENOME_SIZE}

#######################################################################
## Allele specific analysis
#######################################################################

ALLELE_SPECIFIC_SNP =

#######################################################################
## Capture Hi-C analysis
#######################################################################

CAPTURE_TARGET =
REPORT_CAPTURE_REPORTER = 1

#######################################################################
## Digestion Hi-C
#######################################################################

GENOME_FRAGMENT = ${GENOME_FRAGMENT}
LIGATION_SITE = ${LIGATION_SITE}
MIN_FRAG_SIZE = 100
MAX_FRAG_SIZE = 1000000
MIN_INSERT_SIZE = 150
MAX_INSERT_SIZE = 750

#######################################################################
## Hi-C processing
#######################################################################

MIN_CIS_DIST =
GET_ALL_INTERACTION_CLASSES = 1
GET_PROCESS_SAM = 0
RM_SINGLETON = 1
RM_MULTI = 1
RM_DUP = 1

#######################################################################
## Contact Maps
#######################################################################

BIN_SIZE = 20000 40000 150000 500000 1000000
MATRIX_FORMAT = upper

#######################################################################
## Normalization
#######################################################################
MAX_ITER = 100
FILTER_LOW_COUNT_PERC = 0.02
FILTER_HIGH_COUNT_PERC = 0
EPS = 0.1

EOF


#########################



# end
