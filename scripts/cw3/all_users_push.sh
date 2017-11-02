KEY=$1

INPUT=todo.csv
IFS=,

UNQ=$(date "+%Y-%m-%d--%k-%M")

{
    read header;
    while read userName githubName
    do
        echo "Name : $userName";
        echo "Github : $githubName";

        {

            if [[ -f tmp/${userName}/hpce-2017-cw3-${userName}/readme.md ]]; then
                if [[ -f tmp/${userName}/log.txt ]];  then
                    mkdir -p tmp/${userName}/hpce-2017-cw3-${userName}/dt10_logs/${UNQ};
                    cp tmp/${userName}/log.txt tmp/${userName}/hpce-2017-cw3-${userName}/dt10_logs/${UNQ}
                    cp tmp/${userName}.log tmp/${userName}/hpce-2017-cw3-${userName}/dt10_logs/${UNQ}
                    cp -R tmp/${userName}/log tmp/${userName}/hpce-2017-cw3-${userName}/dt10_logs/${UNQ}
                    (cd tmp/${userName}/hpce-2017-cw3-${userName} && git add dt10_logs/${UNQ}/* dt10_logs/${UNQ}/log/*)
                    (cd tmp/${userName}/hpce-2017-cw3-${userName} && git pull)
                    (cd tmp/${userName}/hpce-2017-cw3-${userName} && git commit -m "(AWS) Auto-test for ${UNQ}" dt10_logs/${UNQ}/* dt10_logs/${UNQ}/log/* )
                    (cd tmp/${userName}/hpce-2017-cw3-${userName} && git push)
                fi
            fi

        } 2>&1 | tee ${userName}_push.log
    done
} < $INPUT
