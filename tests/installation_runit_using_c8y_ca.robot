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
    Bootstrap Using Certificate Authority

Install From File Without UPX
    ${file}=    Set Variable    tedge-standalone-arm64-noupx.tar.gz
    Setup Device With Binaries    image=busybox   file=${file}    target_dir=/root
    Install Standalone Binary    ${file}    target_dir=/root
    Bootstrap Using Certificate Authority

Install From URL With UPX
    Skip    TODO
    Setup Device    image=busybox
    DeviceLibrary.Execute Command    cmd=wget -q -O - https://raw.githubusercontent.com/thin-edge/tedge-standalone/main/install.sh | sh -s -- --install-path /data
    Bootstrap Using Certificate Authority

Install From URL Without UPX
    Skip    TODO
    Setup Device    image=busybox
    DeviceLibrary.Execute Command    cmd=wget -q -O - https://raw.githubusercontent.com/thin-edge/tedge-standalone/main/install.sh | sh -s -- --install-path /data --no-upx
    Bootstrap Using Certificate Authority


Install on SysVInit Device
    ${file}=    Set Variable    tedge-standalone-arm64-noupx.tar.gz
    Setup SysVInit Device With Binaries    image=debian:12   file=${file}    target_dir=/root
    Install Standalone Binary    ${file}    target_dir=/root
    Bootstrap Using Certificate Authority

*** Keywords ***

Bootstrap Using Certificate Authority
    [Arguments]    ${install_path}=/data

    ${credentials}=    Cumulocity.Bulk Register Device With Cumulocity CA       external_id=${DEVICE_ID}
    ${c8y_domain}=    Cumulocity.Get Domain
    DeviceLibrary.Execute Command    cmd=/data/tedge/bootstrap.sh --c8y-url '${c8y_domain}' --ca c8y --device-id '${DEVICE_ID}' --one-time-password '${credentials.one_time_password}'
    
    Cumulocity.Device Should Exist    ${DEVICE_ID}
    Cumulocity.Device Should Have Event/s    expected_text=tedge started up.*    type=startup
