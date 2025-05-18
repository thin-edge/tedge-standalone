*** Settings ***
Resource            ./resources/common.resource
Library    Cumulocity
Library    DeviceLibrary

Test Teardown    Stop Device

*** Test Cases ***

Install From File With UPX
    ${file}=    Set Variable    tedge-standalone-${TARGET.name}.tar.gz
    Setup Device With Binaries    image=busybox   file=${file}    target_dir=/root
    Install Standalone Binary    ${file}    target_dir=/root
    Bootstrap Using Self-Signed Certificate

Install From File Without UPX
    ${file}=    Set Variable    tedge-standalone-${TARGET.name}-noupx.tar.gz
    Setup Device With Binaries    image=busybox   file=${file}    target_dir=/root
    Install Standalone Binary    ${file}    target_dir=/root
    Bootstrap Using Self-Signed Certificate

Install From URL With UPX
    Setup Device    image=busybox
    DeviceLibrary.Execute Command    cmd=wget -q -O - https://raw.githubusercontent.com/thin-edge/tedge-standalone/main/install.sh | sh -s -- --install-path /data
    Bootstrap Using Self-Signed Certificate

Install From URL Without UPX
    Setup Device    image=busybox
    DeviceLibrary.Execute Command    cmd=wget -q -O - https://raw.githubusercontent.com/thin-edge/tedge-standalone/main/install.sh | sh -s -- --install-path /data --no-upx
    Bootstrap Using Self-Signed Certificate


*** Keywords ***

Bootstrap Using Self-Signed Certificate
    [Arguments]    ${install_path}=/data

    ${c8y_domain}=    Cumulocity.Get Domain
    DeviceLibrary.Execute Command    cmd=sh -c "env C8Y_USER='${C8Y_CONFIG.username}' C8Y_PASSWORD='${C8Y_CONFIG.password}' /data/tedge/bootstrap.sh --c8y-url '${c8y_domain}' --ca self-signed --device-id '${DEVICE_ID}'"
    
    Cumulocity.Device Should Exist    ${DEVICE_ID}
    Cumulocity.Device Should Have Event/s    expected_text=tedge started up.*    type=startup
