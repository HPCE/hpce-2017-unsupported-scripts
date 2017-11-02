#!/bin/bash

CW_BASE_NAME=hpce-2017-cw3

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

#log_base "Non-authoritative run attempt 3 (previous two died due to out of disk errors)."
#log_base "This is _not_ date-limited, so any changes since deadline would have been picked up."


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


(cd $STAGING_DIR && git log -1)


########################################
## Try building the tools

test_file_exists_and_copy_binary IGNORE src/$SL/step_world_v1_lambda.cpp;

test_file_exists_and_copy_text V1_CPP src/$SL/step_world_v1_lambda.cpp;
test_file_exists_and_copy_text V2_CPP src/$SL/step_world_v2_function.cpp;

test_file_exists_and_copy_text V3_CPP src/$SL/step_world_v3_opencl.cpp;
test_file_exists_and_copy_text V3_CL src/$SL/step_world_v3_kernel.cl;

test_file_exists_and_copy_text V4_CPP src/$SL/step_world_v4_double_buffered.cpp;
if_file_exists_then_copy_text V4_CL src/$SL/step_world_v4_double_buffered.cl; # Not required to exist
if_file_exists_then_copy_text V4_CL src/$SL/step_world_v4_kernel.cl; # My naming convention was stupid, will accept

test_file_exists_and_copy_text V5_CPP src/$SL/step_world_v5_packed_properties.cpp;
# The original names are a little silly
test_file_exists_and_copy_either_text V5_CL src/$SL/step_world_v5_kernel.cl src/$SL/step_world_v5_packed_properties.cl;

mkdir -p $WORKING_DIR/include
cp $SCRIPTS_DIR/include/heat.hpp $WORKING_DIR/include/

CPPDEFAULTS="g++ -std=c++14 -O3 -W -Wall -g -I include -I $SCRIPTS_DIR/include $SCRIPTS_DIR/src/heat.cpp"

echo $exists_V1_CPP;

echo "(cd $WORKING_DIR && $CPPDEFAULTS src/$SL/step_world_v1_lambda.cpp -o step_world_v1_lambda) &> $LOG_DIR/build_v1_lambda.log";
test_command_and_exit_code_conditional exists_V1_CPP \
	"(cd $WORKING_DIR && $CPPDEFAULTS src/$SL/step_world_v1_lambda.cpp -o step_world_v1_lambda) &> $LOG_DIR/build_v1_lambda.log " \
	"Compiling step_world_v1_lambda.cpp"
	
test_command_and_exit_code_conditional exists_V2_CPP \
	"(cd $WORKING_DIR && $CPPDEFAULTS src/$SL/step_world_v2_function.cpp -o step_world_v2_function) &> $LOG_DIR/build_v2_function.log " \
	"Compiling step_world_v2_function.cpp"
		
# Ensure enqueueBarrier is available
CPPDEFAULTS="$CPPDEFAULTS -DCL_USE_DEPRECATED_OPENCL_1_1_APIS"

#CPPDEFAULTS="$CPPDEFAULTS -I $SCRIPTS_DIR/opencl_sdk/include -L $SCRIPTS_DIR/opencl_sdk/lib/cygwin/x86"
#PREPROC="g++ -std=c++0x -I $SCRIPTS_DIR/opencl_sdk/include -I include -I $SCRIPTS_DIR/include -E"
PREPROC="g++ -std=c++14 -I $SCRIPTS_DIR/include  -E"

export HPCE_CL_SRC_DIR="src/$SL";

test_command_and_exit_code '(cd $WORKING_DIR && $PREPROC src/$SL/step_world_v3_opencl.cpp -o -  | $SCRIPTS_DIR/extract_preprocessed_part.pl src/$SL/step_world_v3_opencl.cpp | grep enqueueNDRangeKernel - )' \
	"Checking step_world_v3_opencl actually enqueues a kernel."
	
test_command_and_exit_code_conditional exists_V3_CPP \
	"(cd $WORKING_DIR && $CPPDEFAULTS src/$SL/step_world_v3_opencl.cpp -o step_world_v3_opencl -lOpenCL) &> $LOG_DIR/build_v3_opencl.log " \
	"Compiling step_world_v3_opencl.cpp"
	
test_command_and_exit_code '(cd $WORKING_DIR && $PREPROC src/$SL/step_world_v4_double_buffered.cpp -o - | $SCRIPTS_DIR/extract_preprocessed_part.pl src/$SL/step_world_v4_double_buffered.cpp | grep enqueueBarrier - )' \
	"Checking step_world_v4_double_buffered uses a barrier."
	
test_command_and_exit_code_conditional exists_V4_CPP \
	"(cd $WORKING_DIR && $CPPDEFAULTS src/$SL/step_world_v4_double_buffered.cpp -o step_world_v4_double_buffered -lOpenCL) &> $LOG_DIR/build_v4_double_buffered.log " \
	"Compiling step_world_v4_double_buffered.cpp"
	
test_command_and_exit_code_conditional exists_V5_CPP \
	"(cd $WORKING_DIR && $CPPDEFAULTS src/$SL/step_world_v5_packed_properties.cpp -o step_world_v5_packed_properties -lOpenCL) &> $LOG_DIR/build_v5_packed_properties.log " \
	"Compiling step_world_v5_packed_properties.cpp"
	
MAKE_WORLD=$SCRIPTS_DIR/src/make_world
STEP_WORLD=$SCRIPTS_DIR/src/step_world
COMPARE_WORLDS=$SCRIPTS_DIR/src/compare_worlds

(cd $WORKING_DIR && ($MAKE_WORLD 256 256 > test_${test_index}.input));
(cd $WORKING_DIR && (cat test_${test_index}.input | $STEP_WORLD > test_${test_index}.ref));

test_command_and_exit_code \
	"(cd $WORKING_DIR && (cat test_${test_index}.input | ./step_world_v1_lambda > test_${test_index}.got) && (cat test_${test_index}.got | $COMPARE_WORLDS test_${test_index}.ref) ) &> $LOG_DIR/test_$test_index.log" \
	"Check output of step_world_v1_lambda for one time step versus reference."

test_command_and_exit_code \
	"(cd $WORKING_DIR && $MAKE_WORLD 256 256 | ./step_world_v1_lambda | $COMPARE_WORLDS <($MAKE_WORLD 256 256 | $STEP_WORLD)) &> $LOG_DIR/test_$test_index.log" \
	"Check output of step_world_v1_lambda for one time step versus reference."
	
test_command_and_exit_code \
	"(cd $WORKING_DIR && $MAKE_WORLD 100 200 | ./step_world_v1_lambda 0.5 4 | $COMPARE_WORLDS <($MAKE_WORLD 100 200 | $STEP_WORLD 0.5 4)) &> $LOG_DIR/test_$test_index.log" \
	"Check output of step_world_v1_lambda for four time steps versus reference."


test_command_and_exit_code \
	"(cd $WORKING_DIR && $MAKE_WORLD 256 256 | ./step_world_v2_function | $COMPARE_WORLDS <($MAKE_WORLD 256 256 | $STEP_WORLD))  &> $LOG_DIR/test_$test_index.log" \
	"Check output of step_world_v2_function for one time step versus reference."
	
test_command_and_exit_code \
	"(cd $WORKING_DIR && $MAKE_WORLD 100 200 | ./step_world_v2_function 0.5 4 | $COMPARE_WORLDS <($MAKE_WORLD 100 200 | $STEP_WORLD 0.5 4))  &> $LOG_DIR/test_$test_index.log" \
	"Check output of step_world_v2_function for four time steps versus reference."
	

test_command_and_exit_code \
	"(cd $WORKING_DIR && $MAKE_WORLD 64 64 | ./step_world_v3_opencl | $COMPARE_WORLDS <($MAKE_WORLD 64 64 | $STEP_WORLD ))  &> $LOG_DIR/test_$test_index.log" \
	"Check output of step_world_v3_opencl for one time step versus reference."
	
test_command_and_exit_code \
	"(cd $WORKING_DIR && $MAKE_WORLD 300 60 | ./step_world_v3_opencl 0.2 8 | $COMPARE_WORLDS <($MAKE_WORLD 300 60 | $STEP_WORLD 0.2 8 ))  &> $LOG_DIR/test_$test_index.log" \
	"Check output of step_world_v3_opencl for eight time steps versus reference."
	

test_command_and_exit_code \
	"(cd $WORKING_DIR && $MAKE_WORLD 64 64 | ./step_world_v4_double_buffered | $COMPARE_WORLDS <($MAKE_WORLD 64 64 | $STEP_WORLD )) &> $LOG_DIR/test_$test_index.log" \
	"Check output of step_world_v4_double_buffered for one time step versus reference."
	
test_command_and_exit_code \
	"(cd $WORKING_DIR && $MAKE_WORLD 300 60 | ./step_world_v4_double_buffered 0.3 8 | $COMPARE_WORLDS <($MAKE_WORLD 300 60 | $STEP_WORLD 0.3 8 )) &> $LOG_DIR/test_$test_index.log" \
	"Check output of step_world_v4_double_buffered for eight time steps versus reference."
	
	
test_command_and_exit_code \
	"(cd $WORKING_DIR && $MAKE_WORLD 64 64 | ./step_world_v5_packed_properties | $COMPARE_WORLDS <($MAKE_WORLD 64 64 | $STEP_WORLD )) &> $LOG_DIR/test_$test_index.log" \
	"Check output of step_world_v5_packed_properties for one time step versus reference."
	
test_command_and_exit_code \
	"(cd $WORKING_DIR && $MAKE_WORLD 50 90 | ./step_world_v5_packed_properties 0.4 10 | $COMPARE_WORLDS <($MAKE_WORLD 50 90 | $STEP_WORLD 0.4 10 )) &> $LOG_DIR/test_$test_index.log" \
	"Check output of step_world_v5_packed_properties for ten time steps versus reference."

TIMEFORMAT=%R;

function timeit {
	(cd $WORKING_DIR && <$1 /usr/bin/time -f %e --output=.tmp_time $2 > /dev/null);
	foo=$(cat $WORKING_DIR/.tmp_time);
};
	
$MAKE_WORLD 256 0.1 1 > $WORKING_DIR/input_256.bin;

timeit "input_256.bin" "./step_world_v3_opencl 0.1 2048";
TIME_V3=$foo;

timeit "input_256.bin" "./step_world_v4_double_buffered 0.1 2048";
TIME_V4=$foo;

timeit "input_256.bin" "./step_world_v5_packed_properties 0.1 2048";
TIME_V5=$foo;

test_command_and_output "true" "$TIME_V3 > 1.2 MULT $TIME_V4" "For n=256, steps=2048: Check time for v3 ($TIME_V3) is more than 1.2 x v4 ($TIME_V4)"
test_command_and_output "true" "$TIME_V4 > 1.01 MULT $TIME_V5" "For n=256, steps=2048: Check time for v4 ($TIME_V4) is more than 1.01 (updated) x v5 ($TIME_V5)"

log_base "";
log_base "Passed ${test_passed} out of ${test_index} tests.";
