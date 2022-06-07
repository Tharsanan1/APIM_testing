echo "Hellov : ${HOST_NAME}"
echo "https://${HOST_NAME}/publisher/"
curl --insecure --fail -i -H "Host: am.wso2.com" "https://${HOST_NAME}/publisher/"
curl --insecure --fail -i -H "Host: am.wso2.com" "https://${HOST_NAME}/publisher/"

