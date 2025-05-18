*** Settings ***
Resource            ./resources/common.resource
Library    Cumulocity
Library    DeviceLibrary

Test Teardown    Stop Device

*** Test Cases ***

Install From File With UPX
    ${file}=    Set Variable    tedge-standalone-arm64.tar.gz
    Setup Device With Binaries    image=busybox   file=${file}    target_dir=/root
    Install Standalone Binary    ${file}    target_dir=/root
    Bootstrap Using Basic Authentication

Install From File Without UPX
    ${file}=    Set Variable    tedge-standalone-arm64-noupx.tar.gz
    Setup Device With Binaries    image=busybox   file=${file}    target_dir=/root
    Install Standalone Binary    ${file}    target_dir=/root
    Bootstrap Using Basic Authentication

Install From URL With UPX
    Setup Device    image=busybox
    DeviceLibrary.Execute Command    cmd=wget -q -O - https://raw.githubusercontent.com/thin-edge/tedge-standalone/main/install.sh | sh -s -- --install-path /data
    Bootstrap Using Basic Authentication

Install From URL Without UPX
    Setup Device    image=busybox
    DeviceLibrary.Execute Command    cmd=wget -q -O - https://raw.githubusercontent.com/thin-edge/tedge-standalone/main/install.sh | sh -s -- --install-path /data --no-upx
    Bootstrap Using Basic Authentication


*** Keywords ***

Bootstrap Using Basic Authentication
    [Arguments]    ${install_path}=/data

    ${credentials}=    Cumulocity.Bulk Register Device With Basic Auth       external_id=${DEVICE_ID}
    ${c8y_domain}=    Cumulocity.Get Domain
    DeviceLibrary.Execute Command    cmd=${install_path}/tedge/bootstrap.sh --c8y-url '${c8y_domain}' --device-user ${credentials.username} --device-password '${credentials.password}'
    
    Cumulocity.Device Should Exist    ${DEVICE_ID}
    Cumulocity.Device Should Have Event/s    expected_text=tedge started up.*    type=startup