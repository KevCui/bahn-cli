# bahn-cli ![CI](https://github.com/KevCui/bahn-cli/workflows/CI/badge.svg)

CLI tool for searching train timetable from Deutsche Bahn, aka [DB](https://www.bahn.de/p/view/index.shtml).

## Dependency

- [cURL](https://curl.haxx.se/)
- [jq](https://stedolan.github.io/jq/)
- python3: [hashlib](https://docs.python.org/3/library/hashlib.html)

## How to use

```
Usage:
  ./bahn.sh -d <dep> -a <arr> [-t <date:time>]

Options:
  -d               Departure station name
  -a               Arrival station name
  -t               Departure date:time, like: "20190630:1300"
                   If it's not specified, default current date & time
  -h | --help      Display this help message

Examples:
  - Search next trains from `hamburg` to `berlin`:
    ~$ ./bahn.sh -d 'hamburg hbf' -a 'berlin hbf'

  - Search trains from `hamburg` to `berlin` at `13:30` on `20190730`:
    ~$ ./bahn.sh -d 'hamburg hbf' -a 'berlin hbf' -t '20190730:1330'
```

## Run tests

```
~$ bats test/bahn.bats
```

## Acknowledgment

Inspired by [pajowu/db-python](https://github.com/pajowu/db-python/blob/master/bahn.py)
