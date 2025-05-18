*** Settings ***
Library     Cumulocity
Library     DeviceLibrary    bootstrap_script=/dev/null


*** Variables ***
# Cumulocity settings
&{C8Y_CONFIG}
...                 host=%{C8Y_BASEURL= }
...                 username=%{C8Y_USER= }
...                 password=%{C8Y_PASSWORD= }
...                 tenant=%{C8Y_TENANT= }

# Docker adapter settings (to control which image is used in the system tests).
# The user just needs to set the IMAGE env variable
&{DOCKER_CONFIG}    image=%{TEST_IMAGE=}


*** Keywords ***
Setup Device
    [Arguments]    ${image}=
    ${DEVICE_ID}=    DeviceLibrary.Setup    skip_bootstrap=${True}    image=${image}
    Set Suite Variable    ${DEVICE_ID}


Setup Device With Binaries
    [Arguments]    ${image}=    ${file}=    ${target_dir}=/root
    ${DEVICE_ID}=    DeviceLibrary.Setup    skip_bootstrap=${True}    image=${image}
    Set Suite Variable    ${DEVICE_ID}
    Transfer To Device    ${CURDIR}/../../install.sh    ${target_dir}/
    Transfer To Device    ${CURDIR}/../../${file}    ${target_dir}/

Setup SysVInit Device With Binaries
    [Arguments]    ${image}=debian:12    ${file}=    ${target_dir}=/root
    ${DEVICE_ID}=    DeviceLibrary.Setup    skip_bootstrap=${True}    image=${image}

    Set Suite Variable    ${DEVICE_ID}
    Transfer To Device    ${CURDIR}/../../install.sh    ${target_dir}/
    Transfer To Device    ${CURDIR}/../../${file}    ${target_dir}/

Install Standalone Binary
    [Arguments]    ${file}    ${target_dir}=/root
    DeviceLibrary.Execute Command    cmd=${target_dir}/install.sh --file ${target_dir}/${file}

Stop Device
    Cumulocity.Delete Managed Object And Device User    ${DEVICE_ID}
