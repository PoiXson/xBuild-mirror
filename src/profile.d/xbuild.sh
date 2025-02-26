#!/usr/bin/bash

alias xbuild='clear;xbuild -v -r'

alias genautotools='clear;genautotools'
alias genpom='clear;genpom'
alias genspec='clear;genspec'
alias ximpl='clear;ximplement'

alias phpunit='vendor/bin/phpunit --coverage-html coverage/html'

export XDEBUG_MODE="coverage"


# https://github.com/marco-c/rust-code-coverage-sample
alias cargocov='grcov . --binary-path ./target/debug/ -s . -t html --branch --ignore-not-existing -o ./coverage/'

if [[ -f "$HOME/.cargo/env" ]]; then
	. "$HOME/.cargo/env"
fi
