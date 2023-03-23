#!/usr/bin/env bash

force=true
[ "$1" == force ] && force=true && rm /tmp/setup-wsl.sh

$force || set -e

echo Downloading setup.wsl
[ -e /tmp/setup-wsl.sh ] \
    || curl --progress-bar https://raw.githubusercontent.com/docdnp/wsl-convenience/main/setup-wsl.sh -o /tmp/setup-wsl.sh

BASHRCBAK=~/.bashrc.wsl.convenience.$(date +%y%m%d%H%M%S).bak
echo Backuping bashrc: $BASHRCBAK
cp ~/.bashrc $BASHRCBAK

echo Removing previous version of wsl-convenience functions
perl <<'EOF'
    open F, "<$ENV{HOME}/.bashrc";
    $_ = join('', <F>);
    close F;

    ~s/^## Next lines were added by setup-wsl.sh.*## Previous lines.*?\n$//ms;
    
    open F, ">$ENV{HOME}/.bashrc";
    print F $_;
    close F;
EOF

echo Inserting new version of wsl-convenience functions
bash <(
perl <<'EOF'
    open F, "</tmp/setup-wsl.sh";
    $_ = join('', <F>); 

    ~/(# =.*?WINGET=.*?"\n$)/ms                         && push @F, $1; 
    ~/(# Export WINHOME.*## Previous lines.*?EOF\n)/ms && push @F, $1;

    print join '', @F 
EOF
)
