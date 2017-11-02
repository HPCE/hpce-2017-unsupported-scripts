KEY=$1

INPUT=../student-mappings.csv
IFS=,

{
    read header;
    while read userName githubName
    do
        echo "Name : $userName";
        echo "Github : $githubName";

		GO=0;
		if [[ ! -f tmp/$userName.log ]]; then
			GO=1;
		else
			filesize=$(wc -c <tmp/$userName.log);
			echo "filesize=$filesize";
			if [[ "$filesize" -le 64 ]]; then
				GO=1;
			fi
		fi
		echo "GO=${GO}"
        if [[ "${GO}" -ne "0" ]]; then
            scripts/tests.sh $userName 2>&1 | tee tmp/$userName.log
        fi
    done
} < $INPUT
