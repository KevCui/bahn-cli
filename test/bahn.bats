#!/usr/bin/env bats
#
# How to run:
#   ~$ bats test/bahn.bats

BATS_TEST_SKIPPED=

setup() {
    _SCRIPT="./bahn.sh"
    _DEPARTURE_STATION="toto"
    _ARRIVAL_STATION="tata"
    _TRIP_DATE="20191030:1730"

    _JQ=$(command -v jq)
    _CURL=$(command -v curl)
    _PYTHON=$(command -v python3)

    _TEST_DIR="./test"
    source $_SCRIPT
}

@test "CHECK: command_not_found()" {
    run command_not_found "bats"
    [ "$status" -eq 1 ]
    [ "$output" = "[31mbats[0m command not found!" ]
}

@test "CHECK: check_var(): all mandatory variables are set" {
    run check_var
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "CHECK: check_var(): no \$_DEPARTURE_STATION" {
    unset _DEPARTURE_STATION
    run check_var
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "-d <dep_station> is missing!"$(usage) ]
}

@test "CHECK: check_var(): no \$_ARRIVAL_STATION" {
    unset _ARRIVAL_STATION
    run check_var
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "-a <arr_station> is missing!"$(usage) ]
}

@test "CHECK: check_var(): no \$_TRIP_DATE" {
    unset _TRIP_DATE
    run check_var
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "CHECK: generate_checksum()" {
    run generate_checksum '{"fake": "sexybody"}'
    [ "$status" -eq 0 ]
    [ "$output" = "41c07f11c87792d9ab12c02f55d29c64" ]
}

@test "CHECK: get_station_lid()" {
    call_api() {
        cat "$_TEST_DIR/station.testdata.json"
    }
    run get_station_lid 'moon'
    [ "$status" -eq 0 ]
    [ "$output" = '{"lid":"A=1@O=HAMBURG@X=9997434@Y=53557110@U=80@L=008096009@B=1@p=1560803885@","name":"HAMBURG","type":"S"}' ]
}

@test "CHECK: find_trip()" {
    call_api() {
        cat "$_TEST_DIR/trip.testdata.json"
    }
    run find_trip '$_DEPARTURE_STATION' '$_ARRIVAL_STATION' '$_TRIP_DATE'
    [ "$status" -eq 0 ]
    [ "${lines[1]}" = "2151-2355  02H04       Hamburg Hbf - Berlin Hbf (tief)  2151-2355  ICE  905" ]
    [ "${lines[3]}" = "2157-0230  04H33  8    Hamburg Hbf - Uelzen             2157-2256  ME 82141" ]
    [ "${lines[4]}" = "                  304  Uelzen - Magdeburg-Neustadt      2302-0041  RE  4697" ]
    [ "${lines[5]}" = "                  3    Magdeburg-Neustadt - Berlin Hbf  0046-0230  RE  3143" ]
    [ "${lines[7]}" = "2234-0536  07H02  11   Hamburg Hbf - Hannover Hbf       2234-0056  ME 81643" ]
    [ "${lines[8]}" = "                  9    Hannover Hbf - Berlin Hbf        0240-0536  ICE  949" ]
    [ "${lines[10]}" = "2246-0536  06H50  14   Hamburg Hbf - Bremen Hbf         2246-2341  IC  2021" ]
    [ "${lines[11]}" = "                  5    Bremen Hbf - Hannover Hbf        0013-0140  RE  4445" ]
    [ "${lines[12]}" = "                  9    Hannover Hbf - Berlin Hbf        0240-0536  ICE  949" ]
}
