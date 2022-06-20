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

curl --insecure --fail -i -H "Host: am.wso2.com" "https://${HOST_NAME}/publisher/"
curl --insecure --fail -i -H "Host: am.wso2.com" "https://${HOST_NAME}/publisher/"

