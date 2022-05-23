#!/usr/bin/bash

alias xbuild='clear;xbuild'

# https://github.com/marco-c/rust-code-coverage-sample
alias cargocov='grcov . --binary-path ./target/debug/ -s . -t html --branch --ignore-not-existing -o ./coverage/'

alias genautotools='clear;genautotools'
alias genpom='clear;genpom'
alias genspec='clear;genspec'

alias phpunit='vendor/bin/phpunit -v --coverage-html coverage/html'
