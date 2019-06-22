#!/usr/bin/env bash
#
# Search Deutsche Bahn train timetable
#
#/ Usage:
#/   ./bahn.sh -d <dep> -a <arr> [-t <date:time>]
#/
#/ Options:
#/   -d               Departure station name
#/   -a               Arrival station name
#/   -t               Departure date:time, like: "20190630:1300"
#/                    If it's not specified, default current date & time
#/   -h | --help      Display this help message
#/
#/ Examples:
#/   \e[32m- Search next trains from `hamburg` to `berlin`:\e[0m
#/     ~$ ./bahn.sh -d 'hamburg hbf' -a 'berlin hbf'
#/
#/   \e[32m- Search trains from `hamburg` to `berlin` at `13:30` on `20190730`:\e[0m
#/     ~$ ./bahn.sh -d 'hamburg hbf' -a 'berlin hbf' \e[33m-t '20190730:1330'\e[0m

usage() {
    # Display usage message
    printf "%b\n" "$(grep '^#/' "$0" | cut -c4-)" && exit 0
}

set_var() {
    # Declare variables used in script
    expr "$*" : ".*--help" > /dev/null && usage
    while getopts ":hd:a:t:" opt; do
        case $opt in
            d)
                _DEPARTURE_STATION="$OPTARG"
                ;;
            a)
                _ARRIVAL_STATION="$OPTARG"
                ;;
            t)
                _TRIP_DATE="$OPTARG"
                ;;
            h)
                usage
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                usage
                ;;
        esac
    done

    _URL="https://reiseauskunft.bahn.de/bin/mgate.exe?checksum="

    _CURL=$(command -v curl)
    _JQ=$(command -v jq)
    _PYTHON=$(command -v python3)
    check_command "curl" "$_CURL"
    check_command "jq" "$_JQ"
    check_command "python3" "$_PYTHON"
}

check_command() {
    # Check command if it exists
    # $1: name
    # $2: command
    if [[ ! "$2" ]]; then
        echo "Command \"$1\" not found!" && exit 1
    fi
}

check_var() {
    # Check _DEPARTURE_STATION, _ARRIVAL_STATION
    if [[ -z "$_DEPARTURE_STATION" ]]; then
        echo '-d <dep_station> is missing!' && usage
    fi
    if [[ -z "$_ARRIVAL_STATION" ]]; then
        echo '-a <arr_station> is missing!' && usage
    fi
    if [[ -z "$_TRIP_DATE" ]]; then
        _TRIP_DATE=$(date +%Y%m%d:%H%M)
    fi
}

generate_checksum() {
    # Generate checksum from $1
    # $1: request body / content text
    local secret
    secret="bdI8UVj40K5fvxwf"
    echo "$1$secret" | $_PYTHON -c 'import sys, hashlib; print(hashlib.md5(sys.argv[1].encode("utf-8")).hexdigest())' "$1$secret"
}

call_api() {
    # Call DB API
    # $1: requst body
    $_CURL -sSX GET "${_URL}$(generate_checksum "$1")" -d "$1"
}

get_station_lid() {
    # Return startion lid
    # $1: station name
    local reqBody
    reqBody='{"svcReqL":[{"meth":"LocMatch","req":{"input":{"field":"S","loc":{"name":"'$1'"}}}}],"auth":{"aid":"n91dB8Z77MLdoR0K","type":"AID"},"client":{"id":"DB","name":"DB Navigator","type":"AND","v":19060000},"ver":"1.10","ext":"DB.R15.12.a"}'
    call_api "$reqBody" | $_JQ -r '.svcResL | .[].res.match.locL | .[] | "\({lid:.lid,name:.name,type:.type})"' | head -1
}

find_trip() {
    # Return trip details
    # $1: departure station
    # $2: arrival station
    # $3: trip date:time
    reqBody='{"auth":{"aid":"n91dB8Z77MLdoR0K","type":"AID"},"client":{"id":"DB","name":"DB Navigator","type":"AND","v":19060000},"ext":"DB.R19.04.a","formatted":false,"lang":"eng","svcReqL":[{"cfg":{"polyEnc":"GPA","rtMode":"HYBRID"},"meth":"TripSearch","req":{"outDate":"'${3%%:*}'","outTime":"'${3#*:}'00","arrLocL":['$2'],"depLocL":['$1'],"getPasslist":true,"getPolyline":true,"jnyFltrL":[{"mode":"BIT","type":"PROD","value":"11111111111111"}],"trfReq":{"cType":"PK","jnyCl":2,"tvlrProf":[{"type":"E"}]}}}],"ver":"1.15"}'
    call_api "$reqBody" | $_JQ -r '.svcResL | .[].res.outConL | .[] | "\(.dep.dTimeS[-6:-2])-\(.arr.aTimeS[-6:-2])+\(.dur[:2])H\(.dur[2:-2])+(\(.dep.dTimeR[-6:-2])-\(.arr.aTimeR[-6:-2]))"' | sed -E 's/null//g' | column -t -s '+'
}

main() {
    set_var "$@"
    check_var
    find_trip "$(get_station_lid "$_DEPARTURE_STATION")" "$(get_station_lid "$_ARRIVAL_STATION")" "$_TRIP_DATE"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
