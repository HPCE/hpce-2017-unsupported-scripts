#!/bin/bash
KEY=$1

INPUT=todo.csv
IFS=,

mkdir -p tmp

sudo apt-get -y install dos2unix  perl bc g++ make git

#if [ ! -f scripts/src/make_world ]; then
#    (cd scripts/src &&
#        g++ -O3 -I ../include -o make_world -std=c++11 heat.cpp make_world.cpp &&
#        g++ -O3 -I ../include -o step_world -std=c++11 heat.cpp step_world.cpp &&
#        g++ -O3 -I ../include -o compare_worlds -std=c++11 heat.cpp compare_worlds.cpp
#        );
#fi


{
    read header;
    while read userName githubName
    do
        echo "Name : $userName";
        echo "Github : $githubName";

        if [[ ! -f tmp/$userName.log ]]; then
            scripts/tests.sh $KEY $userName 2>&1 | tee tmp/$userName.log
        fi
    done
} < $INPUT
