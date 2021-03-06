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

set -e
set -u

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

    _CURL=$(command -v curl) || command_not_found "curl"
    _JQ=$(command -v jq) || command_not_found "jq"
    _PYTHON=$(command -v python3) || command_not_found "python"
}

command_not_found() {
    # Show command not found message
    # $1: command name
    printf "%b\n" '\033[31m'"$1"'\033[0m command not found!' && exit 1
}

check_var() {
    # Check _DEPARTURE_STATION, _ARRIVAL_STATION
    if [[ -z "${_DEPARTURE_STATION:-}" ]]; then
        echo '-d <dep_station> is missing!' && usage
    fi
    if [[ -z "${_ARRIVAL_STATION:-}" ]]; then
        echo '-a <arr_station> is missing!' && usage
    fi
    if [[ -z "${_TRIP_DATE:-}" ]]; then
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
    call_api "$reqBody" \
        | $_JQ -r '.svcResL[].res.match.locL[] | "\({lid:.lid,name:.name,type:.type})"' \
        | head -1
}

find_trip() {
    # Return trip details
    # $1: departure station
    # $2: arrival station
    # $3: trip date:time
    reqBody='{"auth":{"aid":"n91dB8Z77MLdoR0K","type":"AID"},"client":{"id":"DB","name":"DB Navigator","type":"AND","v":19060000},"ext":"DB.R19.04.a","formatted":false,"lang":"eng","svcReqL":[{"cfg":{"polyEnc":"GPA","rtMode":"HYBRID"},"meth":"TripSearch","req":{"outDate":"'${3%%:*}'","outTime":"'${3#*:}'00","arrLocL":['$2'],"depLocL":['$1'],"getPasslist":true,"getPolyline":true,"jnyFltrL":[{"mode":"BIT","type":"PROD","value":"11111111111111"}],"trfReq":{"cType":"PK","jnyCl":2,"tvlrProf":[{"type":"E"}]}}}],"ver":"1.15"}'
    call_api "$reqBody" \
        | $_JQ -r '.svcResL[].res.outConL[] | . as $trip | .secL[] | "\(if $trip.dep.dTimeR == null then $trip.dep.dTimeS[-6:-2] else $trip.dep.dTimeR[-6:-2] end)-\(if $trip.arr.aTimeR == null then $trip.arr.aTimeS[-6:-2] else $trip.arr.aTimeR[-6:-2] end)+\($trip.dur[:2])H\($trip.dur[2:-2])+\(if .dep.dPlatfS == null then " " else .dep.dPlatfS end)+\(.jny.ctxRecon | select(.!=null))"' \
        | awk -F'(@O=|@L=|@a=|T\\$A|128@|\\$\\$1)' '{printf "%s%s - %s%s\n", $1, $3, $7, $10}' \
        | sed -E 's/\$/+/g;s/null//g' \
        | awk -F"+" '{printf "%s+%s|%s+%s+%s-%s+%s\n", $1, $2, $3, $4, substr($5,9,12), substr($6,9,12), $7}' \
        | awk -F"|" '{if ($1==prev) printf " + +%s\n", $2; else printf " +\n%s+%s\n", $1, $2; prev=$1}' \
        | column -t -s '+'
}

main() {
    set_var "$@"
    check_var
    find_trip "$(get_station_lid "$_DEPARTURE_STATION")" "$(get_station_lid "$_ARRIVAL_STATION")" "$_TRIP_DATE"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
