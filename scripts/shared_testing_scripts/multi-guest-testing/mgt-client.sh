#!/bin/bash

DEFAULT_SLEEP_TIME=2
PC_NAME_AND_USER="root@localhost:~# "

echo_command() {
    echo "root@localhost:~# $*"
}

step_no_sleep() {
    #echo ""
    #echo "root@localhost:~# $*"
    echo_command "$@"
    sleep $DEFAULT_SLEEP_TIME
    eval "$@"
    echo ""
}

step_sleep_n() {
    local N=$1
    shift
    sleep $N
    step_no_sleep "$@"
}

step() {
    step_sleep_n $DEFAULT_SLEEP_TIME "$@"
}

step_with_timeout() {
    local T=$1
    shift
    echo_command "$@"
    step timeout $T "$@"
}

step_no_sleep() {
    read -r
    echo_command "$@"
    read -r
    eval "$@"
}

wait_for_return() {
    stty -echo
    read -r
    stty echo
}

step() {
    echo_command "$@"
    wait_for_return
    eval "$@"
    wait_for_return
}

step_timeout() {
    local T=$1
    shift
    echo_command "$@"
    wait_for_return
    eval timeout $T "$@"
    wait_for_return
}

echo Press enter to step through the test... printing, then executing...
read -r
step cxl create-region -m -t pmem -d decoder0.0 -w 1 -g 1024 -s 256M mem0
step ndctl create-namespace --region region0 --mode fsdax --size 256M
step_timeout 1 cat /dev/pmem0
step "echo 'HELLO WORLD. REGION0 IS HERE?' > /dev/pmem0"
step_timeout 1 cat /dev/pmem0
step ndctl disable-namespace namespace0.0
step ndctl destroy-namespace namespace0.0
step cxl disable-region region0
step cxl destroy-region region0
step cxl disable-memdev mem0
step "lspci -vt | grep -A4 00:0c && lspci -vt | grep -A4  00:16"
step "lspci -vt | grep -A4 00:0c && lspci -vt | grep -A4  00:16"
step "lspci -vt | grep -A4 00:0c && lspci -vt | grep -A4  00:16"
step cxl create-region -m -t pmem -d decoder0.1 -w 1 -g 1024 -s 256M mem0
step ndctl create-namespace --region region1 --mode fsdax --size 256M
step_timeout 1 cat /dev/pmem1
step "echo 1 > /sys/bus/cxl/devices/mem0/security/sanitize"
step ndctl disable-namespace namespace1.0
step ndctl destroy-namespace namespace1.0
step cxl disable-region region1
step cxl destroy-region region1
step "echo 1 > /sys/bus/cxl/devices/mem0/security/sanitize"
step cxl disable-memdev mem0
step "echo 'Remember to wait 5 seconds before rebinding!'"
