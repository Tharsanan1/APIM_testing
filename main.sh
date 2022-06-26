#!/bin/bash
workingdir=$(pwd)
reldir=`dirname $0`
cd $reldir

echo "Hellov : ${HOST_NAME}"

kubectl get pods -l product=apim -n="${kubernetes_namespace}"  -o custom-columns=:metadata.name > podNames.txt
dateWithMinute=$(date +"%Y_%m_%d_%H_%M")
date=$(date +"%Y_%m_%d")
mkdir -p logs
cat podNames.txt | while read podName 
do
    if [[ "$podName" != "" ]];
    then 
        phase=$(kubectl get pods "$podName" -n="${kubernetes_namespace}" -o json | jq -r '.status | .phase')
        if [[ "$phase" == "Running" ]];
        then 
            kubectl logs "$podName" -n="${kubernetes_namespace}" > "logs/$dateWithMinute-$podName.txt"
        else
            echo "$podName is not running. Its in $phase phase."
        fi
    fi
done

warningPattern="^\[[0-9,: ,-]*\][ ]*WARN - (.*)$"
errorPattern="^\[[0-9,: ,-]*\][ ]*ERROR - (.*)$"

flag="false"

for filename in logs/*; do
    while read line;
    do
        if [[ "$line" =~ $warningPattern || "$line" =~ $errorPattern ]];
        then 
            flag="true"
            match=${BASH_REMATCH[1]}
            while read i;
            do
                if [[ "$match" =~ $i ]];
                then 
                    flag="false"
                    break
                fi
            done <<< $( jq -cr '.[]' excludedWarningsAndErrors.json )
            if [[ $flag == "true" ]];
            then 
                if [[ "$line" =~ $warningPattern ]];
                then 
                    echo "Unexpected warning $line"
                    exit 1
                else 
                    echo "Unexpected error $line"
                    exit 1
                fi
            else 
                echo "Expected $line is ignored."
            fi
        fi
    done <<< $(cat "$filename")
done

# curl --insecure --fail -i -H "Host: am.wso2.com" "https://${HOST_NAME}/publisher/"
# curl --insecure --fail -i -H "Host: am.wso2.com" "https://${HOST_NAME}/publisher/"

mkdir -p ../../output/
mkdir -p ../../output/jmeter-results
rm -f ../../output/jmeter.log
rm -f -r ../../output/jmeter-results
jmeter -n -t APIM-jmeter-test.jmx -Jhost="${HOST_NAME}" -l ../../output/jmeter.log -e -o ../../output/jmeter-results > jmeter-runtime.log
cp jmeter-runtime.log ../../output/jmeter-results/
greppedOutput=$(cat jmeter-runtime.log | grep "end of run" | wc -l)
if [[ "$greppedOutput" == "0" ]]
then
    echo "Could not start jmeter tests."
    exit 1
fi 

greppedOutput=$(cat jmeter-runtime.log | grep "Err:.*(100.00%).*" | wc -l)
if [[ "$greppedOutput" != "0" ]]
then
    echo Jmeter test srcipts failed.
    exit 1
else
    echo All the Jmeter test scripts passed.
    exit 0
fi 


cd "$workingdir"

