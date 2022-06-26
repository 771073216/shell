#!/usr/bin/env bash
apt install -y bash-completion unzip net-tools dnsutils
cat >> "${HOME}"/.bashrc <<- EOF
if [ -x /usr/bin/dircolors ]; then
  test -r ~/.dircolors && eval "\$(dircolors -b ~/.dircolors)" || eval "\$(dircolors -b)"
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
cat >> "${HOME}"/.profile <<- EOF
if [ -f /etc/bash_completion ]; then
. /etc/bash_completion
fi
EOF
