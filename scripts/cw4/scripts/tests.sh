#!/bin/bash

CW_BASE_NAME=hpce-2017-cw4

STUDENT_LOGIN=$1
SUBMISSION_SRC=${CW_BASE_NAME}-$1

SL=$STUDENT_LOGIN;

is_valid_login=$(echo $STUDENT_LOGIN | sed -r -e 's/[0-9a-z]+//g');
if [[ "" -ne is_valid ]]; then
	echo "FATAL ERROR : $STUDENT_LOGIN is not valid.";
	exit 1;
fi


SCRIPT_PATH=$(cd $(dirname $0) && pwd)/$(basename $0);
SCRIPTS_DIR=$(dirname $SCRIPT_PATH);

BASE_DIR=./tmp/$STUDENT_LOGIN;
LOG=$BASE_DIR/log.txt;
STAGING_DIR="$BASE_DIR/${SUBMISSION_SRC}";
WORKING_DIR=$BASE_DIR/working;	# Where we do the compilation etc.
LOG_DIR=$BASE_DIR/log;

if [[ ! -d ${CW_BASE_NAME} ]]; then
	git clone git@github.com:HPCE/${CW_BASE_NAME}.git
fi
DISTRIB_DIR=${CW_BASE_NAME}

CLEAN=1;
if [[ $CLEAN -ne 0 ]]; then

	# Create an absolutely clean working dir
	# Slightly dangerous to have rm -rf in script...
	if [[ -d "$BASE_DIR" ]]; then
		echo "Cleaning working dir.";
		rm -rf "$BASE_DIR";
	fi;
fi;

rm -f $LOG;
test_index=0;
test_passed=0;

mkdir -p $BASE_DIR;
mkdir -p $WORKING_DIR;
mkdir -p $STAGING_DIR;
mkdir -p $LOG_DIR;


function log_base {
	echo $1 >> $LOG;
	echo $1
}

log_base "";
chmod u+rw $LOG;


function if_file_exists_then_copy_text {
	if [[ -f $STAGING_DIR/$2 ]]; then
		eval exists_${1}=1;
		mkdir -p "$(dirname $WORKING_DIR/$2)";
		chmod a+r "$STAGING_DIR/$2"
		cp "$STAGING_DIR/$2" "$WORKING_DIR/$2";
		dos2unix $WORKING_DIR/$2
	fi;
}



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

function test_file_exists_and_copy_script {
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
		chmod u+x "$WORKING_DIR/$2"
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


function test_file_exists_and_copy_either_text {
	if [[ -f $STAGING_DIR/$2 ]]; then
		log_base "${STUDENT_LOGIN}, $test_index, Have $2, PASS";
		eval exists_${1}=1;
		mkdir -p "$(dirname $WORKING_DIR/$2)";
		chmod a+r "$STAGING_DIR/$2"
		cp "$STAGING_DIR/$2" "$WORKING_DIR/$2";
		dos2unix "$WORKING_DIR/$2";
		test_passed=$(($test_passed+1));
    elif [[ -f $STAGING_DIR/$3 ]]; then
		log_base "${STUDENT_LOGIN}, $test_index, Have $3, PASS";
		eval exists_${1}=1;
		mkdir -p "$(dirname $WORKING_DIR/$3)";
		chmod a+r "$STAGING_DIR/$3"
		cp "$STAGING_DIR/$3" "$WORKING_DIR/$3";
		dos2unix "$WORKING_DIR/$3";
		test_passed=$(($test_passed+1));
	else
		log_base "${STUDENT_LOGIN}, $test_index, Have $2 or $3, FAIL";
		eval exists_${1}=0;
	fi;
	test_index=$(($test_index+1));
}

function test_file_built {
	if [[ -f "$WORKING_DIR/$2" ]]; then
		log_base "${STUDENT_LOGIN}, $test_index, Built $2, PASS";
		eval exists_${1}=1;
		test_passed=$(($test_passed+1));
	else
		log_base "${STUDENT_LOGIN}, $test_index, Built $2, FAIL";
		eval exists_${1}=0;
	fi
	test_index=$(($test_index+1));
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

# Check that two files are the same
# $1 - First file
# $2 - Second file
# $3 - Log message
function test_files_same {
	local res;
	(cd $WORKING_DIR && diff $1 $2);
	res=$?;
	if [[ $res -ne 0 ]]; then
		log_base "${STUDENT_LOGIN}, $test_index, Check $1 and $2 are the same : $3, FAIL";
		res=0;
	else
		log_base "${STUDENT_LOGIN}, $test_index, Check $1 and $2 are the same : $3, PASS"
		test_passed=$(($test_passed+1));
		res=1;
	fi
	test_index=$(($test_index+1));
	return $res;	
};

# Check that two files are different
# $1 - First file
# $2 - Second file
# $3 - Log message
function test_files_differ {
	local res;
	(cd $WORKING_DIR && diff $1 $2);
	res=$?;
	if [[ $res -eq 0 ]]; then
		log_base "${STUDENT_LOGIN}, $test_index, Check $1 and $2 are different : $3, FAIL";
		res=0;
	else
		log_base "${STUDENT_LOGIN}, $test_index, Check $1 and $2 are different : $3, PASS"
		test_passed=$(($test_passed+1));
		res=1;
	fi
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
		test_command_and_exit_code "$2" "$3";
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
		test_command_and_output "$2" "$3" "$4";
	fi;

};

######################################################
## First, expand the tar ball and extract the git repo

if [[ ! -f $STAGING_DIR/readme.md ]]; then

	(cd $BASE_DIR && git clone git@github.com:HPCE/${SUBMISSION_SRC}.git )

fi;

if [[ ! -f $STAGING_DIR/readme.md ]]; then
	log_base "$SL, FATAL_ERROR : Git repo didn't contain a src directory.";
	exit 1;
fi;

TIMEFORMAT=%R;

function timeit {
	local dst;
	if (( $# >= 3 )); then
		dst=$3;
	else
		dst="/dev/null";
	fi
	(cd $WORKING_DIR && <$1 /usr/bin/time -f %e --output=.tmp_time $2 > $dst);
	foo=$(cat $WORKING_DIR/.tmp_time);
};


########################################
## Try building the tools

CPPDEFAULTS="g++ -std=c++14 -O3 -W -Wall -g -I include"
LDDEFAULTS="-ltbb -lOpenCL"

# log_base "Note: Performance tests are currently disabled to manage run-time on auto-tests.";
# log_base "It is up to you to check that you are getting decent performance (chunking?)".

#INST_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)
#log_base "Instance type = ${INST_TYPE}"


if [[ "1" ]]; then


cp -r $STAGING_DIR/* "$WORKING_DIR";

test_file_exists_and_copy_script CREATE_N512 scripts/create_n512.sh;

test_file_exists_and_copy_script RUN_512_P1 scripts/run_n512_P1.sh;
test_file_exists_and_copy_script RUN_512_p2 scripts/run_n512_P2.sh;
test_file_exists_and_copy_script RUN_512_p4 scripts/run_n512_P4.sh;
test_file_exists_and_copy_script RUN_512_P8 scripts/run_n512_P8.sh;
test_file_exists_and_copy_script RUN_512_P16 scripts/run_n512_P16.sh;
test_file_exists_and_copy_script RUN_512_P16 scripts/run_n512_P32.sh;

test_file_exists_and_copy_binary FORGET results/pipeline_p_vs_bandwidth.pdf;
test_file_exists_and_copy_binary FORGET results/dependency_sketch.pdf;
test_file_exists_and_copy_binary FORGET results/output_dependency_cone.pdf;
test_file_exists_and_copy_binary FORGET results/single_layer_ratio_vs_time.pdf;
test_file_exists_and_copy_binary FORGET results/single_layer_n_vs_time.pdf;


test_file_exists_and_copy_text PAR_FOR_NAIVE src/layers/par_for_naive_layer.cpp;
test_file_exists_and_copy_text PAR_FOR_ATOMIC src/layers/par_for_atomic_layer.cpp;
test_file_exists_and_copy_text PAR_FOR_ATOMIC src/layers/clustered_layer.cpp;
test_file_exists_and_copy_text PAR_FOR_ATOMIC src/layers/par_for_clustered_layer.cpp;

test_command_and_exit_code \
	"(cd $WORKING_DIR && $CPPDEFAULTS src/util/layer_io.cpp src/tools/generate_sparse_layer.cpp -o bin/generate_sparse_layer $LDDEFAULTS) &> $LOG_DIR/build_generate_sparse_layer.log " \
	"Compiling bin/generate_sparse_layer"

test_command_and_exit_code \
	"(cd $WORKING_DIR && $CPPDEFAULTS src/util/layer_io.cpp src/tools/run_network.cpp src/layers/*.cpp -o bin/run_network $LDDEFAULTS) &> $LOG_DIR/build_run_network.log " \
	"Compiling bin/run_network"

test_command_and_exit_code \
	"(cd $WORKING_DIR && scripts/create_n512.sh) &> $LOG_DIR/run_create_n512.log" \
	"Running scripts/create_n512.sh"
	
test_file_built FORGET w/n512_00.bin
test_file_built FORGET w/n512_31.bin

cat /dev/urandom | head -c 512 > $WORKING_DIR/w/random512.bin
cat /dev/urandom | head -c 65536 > $WORKING_DIR/w/random64K.bin
cat /dev/urandom | head -c 4194304 > $WORKING_DIR/w/random1M.bin


test_command_and_exit_code \
	"(cd $WORKING_DIR && ( cat w/random512.bin | bin/run_network w/n512_00.bin w/n512_01.bin w/n512_02.bin w/n512_03.bin \
        w/n512_04.bin w/n512_05.bin w/n512_06.bin w/n512_07.bin \
        w/n512_08.bin w/n512_09.bin w/n512_10.bin w/n512_11.bin \
        w/n512_12.bin w/n512_13.bin w/n512_14.bin w/n512_15.bin \
        w/n512_16.bin w/n512_17.bin w/n512_18.bin w/n512_19.bin \
        w/n512_20.bin w/n512_21.bin w/n512_22.bin w/n512_23.bin \
        w/n512_24.bin w/n512_25.bin w/n512_26.bin w/n512_27.bin \
        w/n512_28.bin w/n512_29.bin w/n512_30.bin w/n512_31.bin > w/ref512.bin )) &> $LOG_DIR/run_reference.log" \
	"Running reference version on all the n512 networks"

test_command_and_exit_code \
	"(cd $WORKING_DIR && ( cat w/random512.bin | scripts/run_n512_P1.sh > w/n512_P1.bin )) &> $LOG_DIR/run_n512_P1.log" \
	"Running p1 version on all the n512 networks"

test_files_same "w/ref512.bin" "w/n512_P1.bin" \
	"Check p1 version against ref"

test_command_and_exit_code \
	"(cd $WORKING_DIR && ( cat w/random512.bin | scripts/run_n512_P8.sh > w/n512_P8.bin )) &> $LOG_DIR/run_n512_P8.log" \
	"Running p8 version on all the n512 networks"

test_files_same "w/ref512.bin" "w/n512_P8.bin" \
	"Check p8 version against ref"


timeit "w/random1M.bin" "scripts/run_n512_P1.sh";
TIME_P1=$foo;

timeit "w/random1M.bin" "scripts/run_n512_P2.sh";
TIME_P2=$foo;

timeit "w/random1M.bin" "scripts/run_n512_P4.sh";
TIME_P4=$foo;

timeit "w/random1M.bin" "scripts/run_n512_P8.sh";
TIME_P8=$foo;

test_command_and_output "true" "$TIME_P1 > 1.6 MULT $TIME_P2" "For 1M input, check time for P1 ($TIME_P1) is more than 1.6 x P2 ($TIME_P2)"
test_command_and_output "true" "$TIME_P1 > 3.0 MULT $TIME_P4" "For 1M input, check time for P1 ($TIME_P1) is more than 3.0 x P4 ($TIME_P4)"
test_command_and_output "true" "$TIME_P1 > 4.5 MULT $TIME_P8" "For 1M input, check time for P1 ($TIME_P1) is more than 4.5 x P8 ($TIME_P8)"


fi


(cd $WORKING_DIR && bin/generate_sparse_layer 2048 2048 0.75 > w/n2048.bin )


timeit "w/random64K.bin" "bin/run_network w/n2048.bin:simple" "w/n2048_ref.bin";
TIME_SIMPLE=$foo;


timeit "w/random64K.bin" "bin/run_network w/n2048.bin:par_for_naive" "w/n2048_naive.bin";
TIME_NAIVE=$foo;

test_command_and_output "true" "$TIME_SIMPLE < 1.5 MULT $TIME_NAIVE" "For 1M input, check time for simple ($TIME_SIMPLE) is less than 1.5 x par_for_naive ($TIME_NAIVE)"

test_files_differ "w/n2048_ref.bin" "w/n2048_naive.bin" \
	"Check simple version against par_for_naive (should be wrong)"


timeit "w/random64K.bin" "bin/run_network w/n2048.bin:par_for_atomic" "w/n2048_atomic.bin";
TIME_ATOMIC=$foo;

test_command_and_output "true" "1.2 MULT $TIME_SIMPLE < $TIME_ATOMIC" "For 64K input, check time for 1.2 x simple ($TIME_SIMPLE) is less than par_for_atomic ($TIME_ATOMIC)"

test_files_same "w/n2048_ref.bin" "w/n2048_atomic.bin" \
	"Check simple version against par_for_atomic"


timeit "w/random64K.bin" "bin/run_network w/n2048.bin:clustered" "w/n2048_clustered.bin";
TIME_CLUSTERED=$foo;

test_command_and_output "true" "1.2 MULT $TIME_SIMPLE > $TIME_CLUSTERED" "For 1M input, check time for 1.2 x simple ($TIME_SIMPLE) is greater than clustered ($TIME_CLUSTERED)"

test_files_same "w/n2048_ref.bin" "w/n2048_clustered.bin" \
	"Check simple version against clustered"


timeit "w/random64K.bin" "bin/run_network w/n2048.bin:par_for_clustered" "w/n2048_par_for_clustered.bin";
TIME_PAR_FOR_CLUSTERED=$foo;

test_command_and_output "true" "$TIME_SIMPLE > 2.0 MULT $TIME_PAR_FOR_CLUSTERED" "For 1M input, check time for simple ($TIME_SIMPLE) is greater than 2.0 x par_for_clustered ($TIME_PAR_FOR_CLUSTERED)"

test_files_same "w/n2048_ref.bin" "w/n2048_par_for_clustered.bin" \
	"Check simple version against par_for_clustered"



log_base "";
log_base "Passed ${test_passed} out of ${test_index} tests.";
#log_base "Note: final performance tests not run, only correctness.";
