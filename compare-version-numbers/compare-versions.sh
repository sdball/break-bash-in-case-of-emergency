#!/usr/bin/env bash

compare() {
  local _bad_version=$1
  local _current_version=$2
  local _latest

  _latest=$(sort -V <(echo "$_bad_version") <(echo "$_current_version") | tail -1)

  [[ "$_latest" == "$_bad_version" ]] && echo "DANGER" && return

  echo "safe"
}

compare "$@"
