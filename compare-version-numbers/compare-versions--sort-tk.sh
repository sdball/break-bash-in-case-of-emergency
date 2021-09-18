#!/usr/bin/env bash

comparable() {
  echo "$1" | tr - .
}

compare() {
  local _bad_version
  local _current_version
  local _latest

  _bad_version=$(comparable "$1")
  _current_version=$(comparable "$2")
  _latest=$(sort -t. -k 1,1n -k 2,2n -k 3,3n -k 4,4n <(echo "$_bad_version") <(echo "$_current_version") | tail -1)

  [[ "$_latest" == "$_bad_version" ]] && echo "DANGER" && return

  echo "safe"
}

compare "$@"
