#!/bin/bash

STUDENT_LOGIN=$1
SUBMISSION_SRC=hpce-2017-cw2-$1

SL=$STUDENT_LOGIN;

is_valid_login=$(echo $STUDENT_LOGIN | sed -r -e 's/[0-9a-z]+//g');
if [[ "" -ne is_valid ]]; then
	echo "FATAL ERROR : $STUDENT_LOGIN is not valid.";
	exit 1;
fi

SCRIPT_PATH=$(cd $(dirname $0) && pwd)/scripts;
SCRIPTS_DIR=$(dirname $SCRIPT_PATH);


BASE_DIR=./tmp/$STUDENT_LOGIN;
LOG=$BASE_DIR/log.txt;
STAGING_DIR="$BASE_DIR/${SUBMISSION_SRC}";
WORKING_DIR=$BASE_DIR/working;	# Where we do the compilation etc.
LOG_DIR=$BASE_DIR/log;

if [[ ! -d hpce-2017-cw2 ]]; then
	git clone git@github.com:HPCE/hpce-2017-cw2.git
fi
DISTRIB_DIR=hpce-2017-cw2

CLEAN=1;
if [[ $CLEAN -ne 0 ]]; then

	# Create an absolutely clean working dir
	# Slightly dangerous to have rm -rf in script...
	if [[ -d "$BASE_DIR" ]]; then
		echo "Cleaning working dir.";
		rm -rf "$BASE_DIR";
	fi;
fi;

mkdir -p $BASE_DIR;
mkdir -p $WORKING_DIR;
mkdir -p $LOG_DIR;
mkdir -p $STAGING_DIR;


rm -f $LOG;
test_index=0;
test_passed=0;

LOG_THROTTLE=" head -c 1MB "

function log_base {
	echo $1 >> $LOG;
	echo $1
}

log_base "";
chmod u+rw $LOG;


function test_file_exists_and_copy_binary {
	local res;
	if [[ -f $STAGING_DIR/$2 ]]; then
		log_base "${STUDENT_LOGIN}, $test_index, Have $2, PASS";
		eval exists_${1}=1;

		echo "Makeing : $(dirname $WORKING_DIR/$2) in $(pwd)";
		mkdir -p "$(dirname $WORKING_DIR/$2)";
		chmod a+r "$STAGING_DIR/$2"
		echo "cp $STAGING_DIR/$2 $WORKING_DIR/$2";
		cp "$STAGING_DIR/$2" "$WORKING_DIR/$2";
		test_passed=$(($test_passed+1));
		res=1;
	else
		log_base "${STUDENT_LOGIN}, $test_index, Have $2, FAIL";
		eval exists_${1}=0;
		res=0;
	fi;
	test_index=$(($test_index+1));
	return $res;
}


function test_file_exists_and_copy_text {
	local res;
	if [[ -f $STAGING_DIR/$2 ]]; then
		log_base "${STUDENT_LOGIN}, $test_index, Have $2, PASS";
		eval exists_${1}=1;

		echo "Makeing : $(dirname $WORKING_DIR/$2) in $(pwd)";
		mkdir -p "$(dirname $WORKING_DIR/$2)";
		chmod a+r "$STAGING_DIR/$2"
		echo "cp $STAGING_DIR/$2 $WORKING_DIR/$2";
		cp "$STAGING_DIR/$2" "$WORKING_DIR/$2";
		dos2unix "$WORKING_DIR/$2";
		test_passed=$(($test_passed+1));
		res=1;
	else
		log_base "${STUDENT_LOGIN}, $test_index, Have $2, FAIL";
		eval exists_${1}=0;
		res=0;
	fi;
	test_index=$(($test_index+1));
	return $res;
}

function test_file_built {
	local res;
	if [[ -f "$WORKING_DIR/$2" ]]; then
		log_base "${STUDENT_LOGIN}, $test_index, Built $2, PASS";
		eval exists_${1}=1;
		test_passed=$(($test_passed+1));
		res=1;
	else
		log_base "${STUDENT_LOGIN}, $test_index, Built $2, FAIL";
		eval exists_${1}=0;
		res=0;
	fi
	test_index=$(($test_index+1));
	return $res;
}

# Run a command, check that it succeeds
# $1 - Command to run
# $2 - Log message
function test_command_and_exit_code {
	local res;
	echo $1;
	eval "$1";

	if [[ $? -ne 0 ]]; then
		log_base "${STUDENT_LOGIN}, $test_index, $2, FAIL";
		res=0;
	else
		log_base "${STUDENT_LOGIN}, $test_index, $2, PASS";
		test_passed=$(($test_passed+1));
		res=1;
	fi;
	test_index=$(($test_index+1));
	return $res;
};

# Run a command and capture output, then check against a condition (which should be one)
# $1 - Command to run
# $2 - Condition
# $3 - Log message
function test_command_and_output {
	local res;
	echo $1;
	VALUE=$($1);
	VALUE=$(echo $VALUE | head -c 1024 | tr -cd '\11\12\15\40-\176' | sed -r -e 's/[^0-9.]//g')
	COND=$(echo $2 | sed -r -e "s/VALUE/$VALUE/g" );
	#echo "COND = $COND"
	RES=$(echo $COND | sed -r -e 's/MULT/*/g' - | bc);
	#echo "RES = $RES"
	if [[ $RES -ne 1 ]]; then
		log_base "${STUDENT_LOGIN}, $test_index, $3, FAIL";
		res=0;
	else
		log_base "${STUDENT_LOGIN}, $test_index, $3, PASS";
		test_passed=$(($test_passed+1));
		res=1;
	fi;
	test_index=$(($test_index+1));
	return $res;
};

# Run a command, check that it succeeds, but only if variable is true
# $1 - Name of condition variable
# $2 - Command to run
# $3 - Log message
function test_command_and_exit_code_conditional {
	v=${!1};
	if [[ v -ne 1 ]]; then
		log_base "${STUDENT_LOGIN}, $test_index, [$1=$v] $3, FAIL";
		test_index=$(($test_index+1));
		return 0;
	else
		return test_command_and_exit_code "$2" "$3";
	fi;
};

# Run a command, check that output is correct, but only if variable is true
# $1 - Name of condition variable
# $2 - Command to run
# $3 - Conditional expression
# $4 - Log message
function test_command_and_output_conditional {
	v=${!1};
	if [[ v -ne 1 ]]; then
		log_base "${STUDENT_LOGIN}, $test_index, [$1=$v] $4, FAIL";
		test_index=$(($test_index+1));
		return 0;
	else
		return test_command_and_output "$2" "$3" "$4";
	fi;

};


######################################################
## First, expand the tar ball and extract the git repo

#log_base "Non-authorative run as discussed in lecture - formal assesment for marks is proceeding in parallel."
#log_base "No manual checking in this run - if it doesn't compile, that doesn't mean you get zero (though you won't get full marks)."
#log_base "This is also just a straight pull of the repo, so if you have modified it since the submission deadline then it may testing something different ( the final assesment is limited by date)."


if [[ ! -f $STAGING_DIR/readme.md ]]; then

	(cd $BASE_DIR && git clone git@github.com:HPCE/${SUBMISSION_SRC}.git )

fi;

OK=0;
if [[ ! -f $STAGING_DIR/readme.md ]]; then
	OK=1;
fi
if [[ ! -f ${STAGING_DIR}/README.md ]]; then
	OK=1;
fi
if [[ $OK -ne 0 ]]; then
	log_base "$SL, FATAL_ERROR : Git repo didn't contain a src directory.";
	exit 1;
fi;

(cd $STAGING_DIR && git log -1)


########################################
## Sort out all the inputs



test_file_exists_and_copy_binary DUMMY results/direct_inner_versus_k.pdf
test_file_exists_and_copy_binary DUMMY results/direct_outer_time_versus_p.pdf
test_file_exists_and_copy_binary DUMMY results/direct_outer_strong_scaling.pdf
test_file_exists_and_copy_binary DUMMY results/direct_outer_strong_scaling.pdf
test_file_exists_and_copy_binary DUMMY results/fast_fourier_time_vs_recursion_k.pdf
test_file_exists_and_copy_binary DUMMY results/fast_fourier_recursion_versus_iteration.pdf


# 6
test_file_exists_and_copy_text DIRECT_PARFOR_INNER_SRC src/$SL/direct_fourier_transform_parfor_inner.cpp ;
test_file_exists_and_copy_text DIRECT_PARFOR_OUTER_SRC src/$SL/direct_fourier_transform_parfor_outer.cpp ;

# 8
test_file_exists_and_copy_text FFT_TASKGROUP_SRC src/$SL/fast_fourier_transform_taskgroup.cpp ;
test_file_exists_and_copy_text FFT_PARFOR_SRC src/$SL/fast_fourier_transform_parfor.cpp ;
test_file_exists_and_copy_text FFT_PARFOR_SRC src/$SL/fast_fourier_transform_combined.cpp ;


# 11
test_file_exists_and_copy_text FFT_REGISTER_FACTORIES_SRC src/fourier_transform_register_factories.cpp;


log_base "Overwriting files in src directory (except for registry)"

cp $DISTRIB_DIR/src/direct_fourier_transform.cpp $WORKING_DIR/src
cp $DISTRIB_DIR/src/fast_fourier_transform.cpp $WORKING_DIR/src
cp $DISTRIB_DIR/src/fourier_transform.cpp $WORKING_DIR/src
cp $DISTRIB_DIR/src/test_fourier_transform.cpp $WORKING_DIR/src
cp $DISTRIB_DIR/src/time_fourier_transform.cpp $WORKING_DIR/src
mkdir -p $WORKING_DIR/include
cp $DISTRIB_DIR/include/fourier_transform.hpp $WORKING_DIR/include

###########################################
## Try building the thing

SKIP=0

if [[ "$SKIP" -ne 1 ]]; then

BASE_SRCS="direct_fourier_transform.cpp fast_fourier_transform.cpp fourier_transform.cpp fourier_transform_register_factories.cpp";
USER_SRCS="$SL/*.cpp";
# 12
test_command_and_exit_code \
	"(cd $WORKING_DIR/src && g++ -std=c++14 -O3 -msse4 -g -I ../include $BASE_SRCS $USER_SRCS $SCRIPTS_DIR/bench_test_fourier_transform.cpp -o ../test_fourier_transform -ltbb) &> $LOG_DIR/build_test_fourier.log" \
	"Can build test_fourier_transform"

test_command_and_exit_code \
	"(cd $WORKING_DIR/src && g++ -std=c++14 -O3 -msse4 -g -I ../include $BASE_SRCS $USER_SRCS $SCRIPTS_DIR/bench_time_fourier_transform.cpp -o ../time_fourier_transform  -ltbb) &> $LOG_DIR/build_time_fourier.log" \
	"Can build time_fourier_transform"

# 14
test_command_and_exit_code '(cd $WORKING_DIR && /usr/bin/timeout 60 ./test_fourier_transform 2>&1) | grep hpce.direct_fourier_transform -' \
	"Checking test_fourier_transform still lists 'hpce.direct_fourier_transform'"
test_command_and_exit_code '(cd $WORKING_DIR && /usr/bin/timeout 60 ./test_fourier_transform 2>&1) | grep hpce.fast_fourier_transform -' \
	"Checking test_fourier_transform still lists 'hpce.fast_fourier_transform'"

test_command_and_exit_code '(cd $WORKING_DIR && /usr/bin/timeout 60 ./test_fourier_transform 2>&1) | grep hpce.$SL.direct_fourier_transform_parfor_inner -' \
	"Checking test_fourier_transform now lists 'hpce.$SL.direct_fourier_transform_parfor_inner'"
test_command_and_exit_code '(cd $WORKING_DIR && /usr/bin/timeout 60 ./test_fourier_transform 2>&1) | grep hpce.$SL.direct_fourier_transform_parfor_outer -' \
	"Checking test_fourier_transform now lists 'hpce.$SL.direct_fourier_transform_parfor_outer'"

test_command_and_exit_code '(cd $WORKING_DIR && /usr/bin/timeout 60 ./test_fourier_transform 2>&1) | grep hpce.$SL.fast_fourier_transform_parfor -' \
	"Checking test_fourier_transform now lists 'hpce.$SL.fast_fourier_transform_parfor'"
test_command_and_exit_code '(cd $WORKING_DIR && /usr/bin/timeout 60 ./test_fourier_transform 2>&1) | grep hpce.$SL.fast_fourier_transform_taskgroup -' \
	"Checking test_fourier_transform now lists 'hpce.$SL.fast_fourier_transform_taskgroup'"
test_command_and_exit_code '(cd $WORKING_DIR && /usr/bin/timeout 60 ./test_fourier_transform 2>&1) | grep hpce.$SL.fast_fourier_transform_combined -' \
	"Checking test_fourier_transform now lists 'hpce.$SL.fast_fourier_transform_combined'"

# 21
test_command_and_exit_code '(cd $WORKING_DIR/src && g++ -std=c++14 -E -I ../include $SL/direct_fourier_transform_parfor_inner.cpp -o -) \
	| $SCRIPTS_DIR/extract_preprocessed_part.pl $SL/direct_fourier_transform_parfor_inner.cpp \
	| grep parallel_for -' \
	"Checking direct_fourier_transform_parfor_inner.cpp calls parallel_for at some point."
test_command_and_exit_code '(cd $WORKING_DIR/src && g++ -std=c++14 -E -I ../include $SL/direct_fourier_transform_parfor_inner.cpp -o -) \
	| $SCRIPTS_DIR/extract_preprocessed_part.pl $SL/direct_fourier_transform_parfor_inner.cpp \
	| grep partitioner -' \
	"Checking direct_fourier_transform_parfor_inner.cpp uses partitioner."
test_command_and_exit_code '(cd $WORKING_DIR/src && g++ -std=c++14 -E -I ../include $SL/direct_fourier_transform_parfor_outer.cpp -o -) \
	| $SCRIPTS_DIR/extract_preprocessed_part.pl $SL/direct_fourier_transform_parfor_outer.cpp \
	| grep parallel_for -' \
	"Checking direct_fourier_transform_parfor_outer.cpp calls parallel_for at some point."

# 24
test_command_and_exit_code '(cd $WORKING_DIR/src && g++ -std=c++14 -E -I ../include $SL/fast_fourier_transform_taskgroup.cpp -o -) \
	| $SCRIPTS_DIR/extract_preprocessed_part.pl $SL/fast_fourier_transform_taskgroup.cpp \
	| grep task_group -' \
	"Checking fast_fourier_transform_taskgroup.cpp uses task groups at some point."
test_command_and_exit_code '(cd $WORKING_DIR/src && g++ -std=c++14 -E -I ../include $SL/fast_fourier_transform_parfor.cpp -o -) \
	| $SCRIPTS_DIR/extract_preprocessed_part.pl $SL/fast_fourier_transform_parfor.cpp \
	| grep parallel_for -' \
	"Checking fast_fourier_transform_parfor.cpp uses parallel_for at some point."
test_command_and_exit_code '(cd $WORKING_DIR/src && g++ -std=c++14 -E -I ../include $SL/fast_fourier_transform_combined.cpp -o -) \
	| $SCRIPTS_DIR/extract_preprocessed_part.pl $SL/fast_fourier_transform_combined.cpp \
	| grep parallel_for -' \
	"Checking fast_fourier_transform_combined.cpp uses parallel_for."
test_command_and_exit_code '(cd $WORKING_DIR/src && g++ -std=c++14 -E -I ../include $SL/fast_fourier_transform_combined.cpp -o -) \
	| $SCRIPTS_DIR/extract_preprocessed_part.pl $SL/fast_fourier_transform_combined.cpp \
	| grep task_group -' \
	"Checking fast_fourier_transform_combined.cpp also uses task_group."

fi;

TIMELIMIT=60
MAXLIMIT=70

if [[ "$SKIP" -ne 1 ]]; then

# 28
test_command_and_exit_code '[[ -f $WORKING_DIR/test_fourier_transform ]] && ( /usr/bin/timeout -k ${MAXLIMIT} ${TIMELIMIT} $WORKING_DIR/test_fourier_transform hpce.$SL.direct_fourier_transform_parfor_inner ) 2>&1 | ${LOG_THROTTLE} > $LOG_DIR/test_direct_fourier_transform_parfor_inner.log' \
	"Testing direct_fourier_transform_parfor_inner (using external tester), every test should pass."

test_command_and_exit_code '[[ -f $WORKING_DIR/test_fourier_transform ]] && ( /usr/bin/timeout -k ${MAXLIMIT} ${TIMELIMIT} $WORKING_DIR/test_fourier_transform hpce.$SL.direct_fourier_transform_parfor_outer ) 2>&1  | ${LOG_THROTTLE} > $LOG_DIR/test_direct_fourier_transform_parfor_outer.log' \
	"Testing direct_fourier_transform_parfor_outer (using external tester), every test should pass."

test_command_and_exit_code '[[ -f $WORKING_DIR/test_fourier_transform ]] && ( /usr/bin/timeout -k ${MAXLIMIT} ${TIMELIMIT} $WORKING_DIR/test_fourier_transform hpce.$SL.fast_fourier_transform_taskgroup ) 2>&1  | ${LOG_THROTTLE} > $LOG_DIR/test_fast_fourier_transform_taskgroup.log' \
	"Testing fast_fourier_transform_taskgroup (using external tester), every test should pass."

test_command_and_exit_code '[[ -f $WORKING_DIR/test_fourier_transform ]] && ( /usr/bin/timeout -k ${MAXLIMIT} ${TIMELIMIT} $WORKING_DIR/test_fourier_transform hpce.$SL.fast_fourier_transform_parfor ) 2>&1  | ${LOG_THROTTLE} > $LOG_DIR/test_fast_fourier_transform_parfor.log' \
	"Testing fast_fourier_transform_parfor (using external tester), every test should pass."

test_command_and_exit_code '[[ -f $WORKING_DIR/test_fourier_transform ]] && ( /usr/bin/timeout -k ${MAXLIMIT} ${TIMELIMIT} $WORKING_DIR/test_fourier_transform hpce.$SL.fast_fourier_transform_combined ) 2>&1  | ${LOG_THROTTLE} > $LOG_DIR/test_fast_fourier_transform_combined.log' \
	"Testing fast_fourier_transform_combined (using external tester), every test should pass."

fi;


function get_command_parallelism {
	TT=$( $1  | ${LOG_THROTTLE} 2> $LOG_DIR/test_$test_index.log );
	if [[ $? != 0 ]]; then
		parallelism="0";
	else
		parallelism=$(echo $TT | sed -n -r -e "s/parallelism = ([0-9\.e+\-]+),.*/\1/p" -);

	fi
};

if [[ "$SKIP" -ne 1 ]]; then

# 33
get_command_parallelism "/usr/bin/timeout -k ${MAXLIMIT} ${TIMELIMIT} $WORKING_DIR/time_fourier_transform hpce.$SL.fast_fourier_transform_taskgroup 4 20";
test_command_and_output "echo parallelism = X $parallelism X"  "$parallelism > 2.5" "Timing hpce.$SL.fast_fourier_transform_taskgroup with 4 CPUs and n=2^20: check observed parallelism (totalTime/wallTime) of $parallelism is more than 2.5.";

get_command_parallelism "/usr/bin/timeout -k ${MAXLIMIT} ${TIMELIMIT} $WORKING_DIR/time_fourier_transform hpce.$SL.fast_fourier_transform_parfor 4 24";
test_command_and_output "echo parallelism = X $parallelism X"   "$parallelism > 1.1" "Timing hpce.$SL.fast_fourier_transform_parfor with 4 CPUs and n=2^24: check observed parallelism (totalTime/wallTime) of $parallelism is more than 1.1.";

get_command_parallelism "/usr/bin/timeout -k ${MAXLIMIT} ${TIMELIMIT} $WORKING_DIR/time_fourier_transform hpce.$SL.fast_fourier_transform_combined 4 20";
test_command_and_output "echo parallelism = $parallelism"  "$parallelism > 2.5" "Timing hpce.$SL.fast_fourier_transform_combined with 4 CPUs and n=2^20: check observed parallelism (totalTime/wallTime) of $parallelism is more than 2.5.";

fi

function get_command_timing {
	TT=$( $1 2> $LOG_DIR/test_$test_index.log );

	if [[ $? != 0 ]]; then
		timing="CommandFailed";
	else
		timing=$(echo $TT | sed -n -r -e "s/.*, time = ([0-9\.e+\-]+)/\1/p" -);
	fi;
};

if [[ "$SKIP" -ne 1 ]]; then

get_command_timing "/usr/bin/timeout -k ${MAXLIMIT} ${TIMELIMIT} $WORKING_DIR/time_fourier_transform hpce.direct_fourier_transform 4 12 ";
timing_direct_serial=$timing;

get_command_timing "/usr/bin/timeout -k ${MAXLIMIT} ${TIMELIMIT} $WORKING_DIR/time_fourier_transform hpce.$SL.direct_fourier_transform_parfor_inner 4 12"
timing_direct_parfor_inner=$timing;
test_command_and_output "true"  "$timing_direct_serial > $timing_direct_parfor_inner" "For 4 CPUs, n=2^12, direct: check time for serial ($timing_direct_serial) is greater than parfor ($timing_direct_parfor_inner).";

get_command_timing "/usr/bin/timeout -k ${MAXLIMIT} ${TIMELIMIT} $WORKING_DIR/time_fourier_transform hpce.fast_fourier_transform 4 22"
timing_fast_serial=$timing;
get_command_timing "/usr/bin/timeout -k ${MAXLIMIT} ${TIMELIMIT} $WORKING_DIR/time_fourier_transform hpce.$SL.fast_fourier_transform_parfor 4 22"
timing_fast_parfor=$timing;
get_command_timing "/usr/bin/timeout -k ${MAXLIMIT} ${TIMELIMIT} $WORKING_DIR/time_fourier_transform hpce.$SL.fast_fourier_transform_taskgroup 4 22 "
timing_fast_taskgroup=$timing;
get_command_timing "/usr/bin/timeout -k ${MAXLIMIT} ${TIMELIMIT} $WORKING_DIR/time_fourier_transform hpce.$SL.fast_fourier_transform_combined 4 22"
timing_fast_combined=$timing;

test_command_and_output "true"  "$timing_fast_serial > 2 MULT $timing_fast_taskgroup" "For 4 CPUs, n=2^22, fast: check time for serial ($timing_fast_serial) is at least 2x that of taskgroup ($timing_fast_taskgroup).";

test_command_and_output "true"  "2 MULT $timing_fast_parfor > 3 MULT $timing_fast_combined" "For 4 CPUs, n=2^22, fast: check time for parfor ($timing_fast_parfor) is at least 1.5x that of combined ($timing_fast_combined).";
#test_command_and_output "true"  "9 MULT $timing_fast_taskgroup < 10 MULT $timing_fast_combined" "For 4 CPUs, n=2^22, fast: check time for taskgroup ($timing_fast_taskgroup) is no more than 0.9x that of combined  ($timing_fast_combined).";

fi;

log_base "";
log_base "Passed ${test_passed} out of ${test_index} tests.";
