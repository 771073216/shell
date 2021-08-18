#!/usr/bin/env bash
apt install bash-completion unzip net-tools
var0=$(echo "\$(dircolors -b ~/.dircolors)")
var1=$(echo "\$(dircolors -b)")
cat >> .bashrc <<- EOF
if [ -x /usr/bin/dircolors ]; then
  test -r ~/.dircolors && eval "$var0" || eval "$var1"
  alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
       #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
        alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
EOF
cat >> .profile <<- EOF
if [ -f /etc/bash_completion ]; then
. /etc/bash_completion
fi
EOF
source .bashrc
source .profile
