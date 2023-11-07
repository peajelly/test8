@echo off
:: Copyright 2019 Huawei Technologies Co., Ltd. All rights reserved.
::
:: DDK wrapper for multi-version execution

setlocal enabledelayedexpansion

set "SCRIPT=%~f0"
for %%A in ("%SCRIPT%") do set "SCRIPTPATH=%%~dpA"
set "CUR_PATH=%CD%"
cd /d "!SCRIPTPATH!"

for /f %%I in ('dir /b /ad /on "V[0-9]*"') do (
    set "V_dir=%%I"
    goto :found
)
:found

:: Default version as master
cd /d "!CUR_PATH!"
if exist "!SCRIPTPATH!\master" (
    set "HIAI_VERSION=master"
) else (
    if exist "!SCRIPTPATH!\IR" (
        set "HIAI_VERSION=IR"
    ) else (
        set "HIAI_VERSION=!V_dir!"
    )
)

:: Command line arguments
set "ARGS=%*"
for %%A in (%ARGS%) do (
    set "ARGS=!ARGS! %%~A"
)

:: Judge if the -execute_device_config argument is present
set "execute_device_switch=0"
for %%A in (!ARGS!) do (
    set "arg=%%~A"
    if /i "!arg!"=="-execute_device_config" set "execute_device_switch=1"
    if /i "!arg!"=="--execute_device_config" set "execute_device_switch=1"
    if /i "!arg!"=="-mode=4" set "execute_device_switch=1"
    if /i "!arg!"=="--mode=4" set "execute_device_switch=1"
)

:: Get the hiai_version argument if present
for %%A in (!ARGS!) do (
    set "arg=%%~A"
    if /i "!arg:~0,14!"=="-hiai_version=" (
        set "HIAI_VERSION=!arg:~14!"
        if !execute_device_switch! equ 0 (
            set "ARGS=!ARGS:%%~A=!"
        )
    )
    if /i "!arg!"=="-hiai_version" (
        set "next=1"
        for %%B in (!ARGS!) do (
            if !next! equ 1 (
                set "HIAI_VERSION=%%~B"
                set "next=0"
            )
            if !execute_device_switch! equ 0 (
                set "ARGS=!ARGS:%%~A %%~B=!"
            )
        )
    )
)

:: Convert the HIAI_VERSION to uppercase
for /f %%A in ('echo !HIAI_VERSION!') do set "HIAI_VERSION=%%A"
for /f %%A in ('echo !HIAI_VERSION!') do set "hiai_version=%%A"

:: Set tbe_lib path
set "tbe_lib=!SCRIPTPATH!\..\..\ddk\tbe\lib64"

:: Set OMG and LD_LIBRARY_PATH based on the HIAI_VERSION and execute_device_switch
if !execute_device_switch! equ 1 (
    if exist "!SCRIPTPATH!\master" (
        set "LD_LIBRARY_PATH=!SCRIPTPATH!\master\lib64;!tbe_lib!"
        set "OMG=!SCRIPTPATH!\master\omg"
    ) else (
        set "LD_LIBRARY_PATH=!SCRIPTPATH!\IR\lib64;!tbe_lib!"
        set "OMG=!SCRIPTPATH!\IR\omg"
    )
) else (
    if not exist "!SCRIPTPATH!\!HIAI_VERSION!" (
        echo "ERROR: version dir !HIAI_VERSION! not exists!"
        exit /b 1
    )
    set "HIAI_VERSION=!HIAI_VERSION!"
    if exist "!SCRIPTPATH!\!hiai_version!" (
        set "HIAI_VERSION=!hiai_version!"
    )
    set "LD_LIBRARY_PATH=!SCRIPTPATH!\!HIAI_VERSION!\lib64;!tbe_lib!"
    set "OMG=!SCRIPTPATH!\!HIAI_VERSION!\omg"
)

:: Set GLIBC_DIR and create a symlink to ld-linux-x86-64.so.2
set "GLIBC_DIR=!SCRIPTPATH!\!HIAI_VERSION!\x86_64-pc-linux-gnu-6.3.0"
if not exist "!TEMP!\x86_64-pc-linux-gnu-6.3.0\ld-linux-x86-64.so.2" (
    rmdir /s /q "!TEMP!\x86_64-pc-linux-gnu-6.3.0"
    mklink /d "!TEMP!\x86_64-pc-linux-gnu-6.3.0" "!GLIBC_DIR!"
)
copy /y "!GLIBC_DIR!\ld-linux-x86-64.so.2" "!TEMP!\x86_64-pc-linux-gnu-6.3.0\ld-linux-x86-64.so.2"

:: Set PATH for ccec_compiler
set "ccec_lib=!SCRIPTPATH!\..\..\ddk\ccec_compiler\bin"
set "PATH=!ccec_lib!;!PATH!"

:: Check if OMG exists and execute it
if not exist "!OMG!" (
    echo "ERROR: !OMG! not exists!"
    exit /b 1
)
set "omg_path=!OMG!"
echo INFO: execute command: !omg_path! !ARGS!
!OMG! !ARGS!

:: Exit with the result code
exit /b %errorlevel%
