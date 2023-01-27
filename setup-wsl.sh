#!/bin/bash
# set -x 
set -e 

# =======================================================================================================================
# HELPER FUNCTIONS 
# =======================================================================================================================
distro   () { cat /etc/*-release  | grep ^ID=       | sed -re 's|ID=||' ; }
parent   () { cat /etc/*-release  | grep ^ID_LIKE=  | sed -re 's|ID=||' ; }
unixpath () { sed -re 's|\\|/|g' -e 's|[\r\n]||g' -e 's| |\\ |g' ; }
wintool  () { wslpath -u "$(/mnt/c/Windows/system32/where.exe "$@" 2>/dev/null | head -1 )" 2>/dev/null | unixpath; }
contains () { grep "$1" >&/dev/null; }
installed() { command -v "$1" >&/dev/null; }
havepkg  () { dpkg -l "$1" | contains ^ii; }
mkwrapper() { echo "Installing win tool wrapper: $1"; echo -e "#!/bin/bash\n$2 \"\$@\"" > ~/.local/bin/$1; chmod +x ~/.local/bin/$1; }
wslcfgget() { crudini --get /etc/wsl.conf "$1" "$2" ; }
wslcfgset() { echo "Setting WSL config: $1.$2 = $3"; crudini --set /etc/wsl.conf "$@" ; }
sudofunc () { local func=$1; shift; sudo bash -c "$(declare -f $func); $func \"$1\" \"$2\" \"$3\"" ; }

# =======================================================================================================================
# CHECK PRECONDITIONS:
#  * We are on disro based on debian
#  * Need 'crudini', 'curl'
#  * Want bash-completion
#  * Want latest PowerShell
# =======================================================================================================================
echo "Checking preconditions... "
{ distro; parent; } | contains debian || {
    echo "Error: Tool 'crudini' is missing. Only debian based distributions are supported."
    echo "If you install 'crudini' manually, the script will continue."
    exit 1
}
DISTRO=$(distro)

installed crudini || {
    sudo apt update
    echo "Installing helper tool: crudini"
    sudo apt install -y crudini
}
installed curl              || sudo apt install -y curl
havepkg   bash-completion   || sudo apt install -y bash-completion

WINGET="$(wintool winget.exe)"
$WINGET list  --accept-source-agreements | contains Microsoft.PowerShell || winget install Microsoft.PowerShell
# =======================================================================================================================
# GET WINHOME
# =======================================================================================================================
echo -n "Checking HOME under Windows... "
POWERSHELL="$(wintool pwsh.exe)"
[ -z "$POWERSHELL" ] && POWERSHELL="$(wintool Powershell)"
WINHOME="$( bash -c "$POWERSHELL -c 'echo \$HOME'" | unixpath | xargs wslpath -u )" 
echo "WINHOME=$WINHOME"

mkdir -p $WINHOME/AppData/Local/Docker; 
mkdir -p ~/.local/bin

# =======================================================================================================================
# GIT WIN & LINUX: 
#  * https://winget.run/pkg/Git/Git
#  * https://github.com/git-guides/install-git
# =======================================================================================================================
PKGS=(Git.Git GitHub.GitLFS Microsoft.GitCredentialManagerCore)
$WINGET list |  perl -ne 'BEGIN{ @P=qw('"${PKGS[*]}"'); $p=join("|", @P)} /$p/ && $i++; END{ exit ($i == @P ? 0 : 1) }'

[ "$?" != 0 ] && {
    echo "Installing Git for Windows..."
    for pkg in ${PKGS[*]} ; do
        pkg_short=$(echo $pkg | sed -re 's|.*\.||')
        echo " installing..."
        $WINGET install --silent $pkg
    done
}
installed apt && {
    installed git || {
        echo "Installing Git for debian based linux..."
        sudo apt install -y git-all 
    }
}

# =======================================================================================================================
# GIT CREDENTIAL MGR: https://learn.microsoft.com/en-us/windows/wsl/tutorials/wsl-git
# =======================================================================================================================
GITCREDMGR="$(wintool /R 'C:\Program Files' git-credential-manager.exe)"
WHOAMI=$(wintool whoami.exe)
WINUSER=$($WHOAMI | sed -re 's/.*\\|\r|\n//g')
EMAIL=$($WHOAMI /UPN)

git config --global --get user.name | contains "$WINUSER" || {
    echo "Setting up git... "
    echo "Setting up git...  user: $WINUSER"
    echo "Setting up git... email: $EMAIL"
    echo "Setting up git... credential manager: $GITCREDMGR"

    git config --global user.name  "$WINUSER"
    git config --global user.email "$EMAIL"
    git config --global credential.helper ~/.local/bin/git-credential-manager
}

# =======================================================================================================================
# ACCESS OTHER DISTROS' FILES:
#  * https://superuser.com/questions/1659218/is-there-a-way-to-access-files-from-one-wsl-2-distro-image-in-another-one
#  * https://askubuntu.com/questions/1395780/accessing-ubuntu-wsl-files-from-kali-wsl-and-vice-versa/1395784#1395784
# =======================================================================================================================
cat /etc/fstab | contains /mnt/wsl/instances/$WSL_DISTRO_NAME || {
    echo "Setting up sharing of filesystems between different WSL distros."
    echo "/ /mnt/wsl/instances/$WSL_DISTRO_NAME none defaults,bind,X-mount.mkdir 0 0" \
        | sudo tee -a /etc/fstab
}

wslcfgget boot      systemd           | contains true  || sudofunc wslcfgset boot systemd true
wslcfgget boot      command           | contains sleep || sudofunc wslcfgset boot command "sleep 5; mount -a"
wslcfgget interop   appendWindowsPath | contains false || sudofunc wslcfgset interop appendWindowsPath false
wslcfgget automount mountFsTab        | contains false || sudofunc wslcfgset automount mountFsTab false

# =======================================================================================================================
# WSL HELPERS BASHRC: https://github.com/docdnp/wsl-convenience
# =======================================================================================================================
grep "added by setup-wsl.sh" ~/.bashrc >&/dev/null || {
echo "Adding helpful stuff to ~/.bashrc"

# Export WINHOME and basic aliases
cat <<EOF >> ~/.bashrc
## Next lines were added by setup-wsl.sh
export WINHOME="$WINHOME"
export PATH=~/.local/bin:\$PATH
alias where=/mnt/c/Windows/system32/where.exe
alias pwsh=$POWERSHELL
EOF

# Provide a 'which' like tool for windows executables
cat <<EOF >> ~/.bashrc
__wsl_which_usage () {
cat <<EOT
Usage: wsl-which [OPTS|GREP]
    -u, --update        reload the cache file
    -i                  use case insensitive grep pattern 
    -h, --help          show this help
EOT
}

wsl-which () {
    local pattern whichcache=/tmp/wsl-which.db grepi=""
    local exts=('*.exe' '*.cmd' '*.com' '*.cpl' '*.msc' '*.ps1' '*.vbs' '*.wsf')
    while [ \$# -gt 0 ] ; do
        case "\$1" in
            -h|--help)  __wsl_which_usage; return;;
            -u|--update) shift; rm -f "\$whichcache";;
            -i) grepi=i; shift ;; 
            -*) echo "Unknown opt: \$1"; __wsl_which_usage; return;;
            *) pattern=\$1; shift; 
        esac
    done
    pattern=\${pattern:-.}

    [ -r "\$whichcache" ] || {
        { where \${exts[@]};
          local IFS=$'\n'
          for i in \$WINHOME \$(ls -1d /mnt/c/Pr*) ; do
            where -R "\$(wslpath -w ""\$i"")" "\${exts[@]}" 2>/dev/null 
          done; } \\
                | perl -pe 's|\\\\|/|g' \\
                | xargs -i wslpath -u '{}' \\
                | perl -pe 's| |\\\\ |g ; s|\r||g'
    } | sort -u > \$whichcache
    grep --color=never -E\$grepi ".*/\$pattern" \$whichcache 
}
EOF

# Provide a tool to create aliases or function wrappers mostly for windows
# executables 
cat <<EOF >> ~/.bashrc
to-alias () { 
    local aliases=\${1:-~/.bash_aliases}
    perl -pe '
        sub p { 
            (\$cmdname, \$global_path, \$ext) = @_;
                \$ext !~ /^ exe \$/ix && do {
                      \$global_path =~ s|\\ | |g;
                      \$global_path = \`wslpath -m "\$global_path" | tr -d "\n"\`;
                      \$global_path =~ s| |\\ |g;
                      \$global_path = " pwsh -c \"'"& '\$global_path"'";
                      \$func = "\$cmdname () {".
                                  \$global_path  
                              ."'"'"' \$@\"; }";
                      return \$func
                    }; 
                return "alias \$cmdname=\"\$global_path\""
            }
            s{ ^(.*/(.*)\.(.*?)?)\n\$ }
             {  sprintf(
                     "%-120s # %s\n"
                      , p(lc(\$2), \$1, \$3)
                      , "added by \"to-alias\""
                )
             }ex' | tee /dev/stderr >> \$aliases
}
EOF

# Provide an 'uninstaller'
cat <<EOF >> ~/.bashrc
wsl-convenience-uninstall () {
    local PKGS=(docker-credential-wincred
                git-credential-manager
                powershell
                winget
                wsl
    )
    for i in \${PKGS[@]} ; do rm ~/.local/bin/\$i ; done
    sed -i '/^## Next.*setup-wsl.sh/,/^## Prev.*setup-wsl.sh/{//!d}' ~/.bashrc;
    sed -ire 's/^.*setup-wsl.sh.*//g' ~/.bashrc
} 
EOF

# Open duplicated tabs of a distro in the current directory
# of another distro and set tab title: 
#
#  * https://learn.microsoft.com/en-us/windows/terminal/tutorials/new-tab-same-directory
#  * https://learn.microsoft.com/en-us/windows/terminal/tutorials/tab-title
#
cat <<EOF >> ~/.bashrc
my_prompt () { printf "\e]9;9;%s\e\\\\" "\$(wslpath -w "\$PWD")" ; }
export PROMPT_COMMAND=my_prompt

PS1='\${debian_chroot:+(\$debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
PS1="\[\e]0;\${WSL_DISTRO_NAME}: \w\a\]\$PS1"

## Previous lines were added by setup-wsl.sh
EOF
}

# =======================================================================================================================
# INPUTRC: https://github.com/docdnp/inputrc
# =======================================================================================================================
curl https://raw.githubusercontent.com/docdnp/inputrc/main/shell.inputrc -o /tmp/.inputrc >&/dev/null

if [ -e ~/.inputrc ] ; then 
    diff ~/.inputrc /tmp/.inputrc >& /dev/null || {
        echo "Backup .inputrc and overwriting it..."
        cp ~/.inputrc ~/.inputrc.$(date +%Y%M%D.setup-wsl)
        mv /tmp/.inputrc ~/.inputrc
    }
else
    echo "Creating .inputrc..."
    mv /tmp/.inputrc ~/.inputrc
fi

# =======================================================================================================================
# Docker: https://docs.docker.com/engine/install/
# =======================================================================================================================
DOCKERCRED="$WINHOME/AppData/Local/Docker/docker-credential-wincred"
! [ -e "$DOCKERCRED" ] && {
    echo "Setting up docker and docker credential helper."
    curl https://github.com/docker/docker-credential-helpers/releases 2>/dev/null \
        | perl -ne '/(\/docker.*checksums\.txt)/ && do { 
            open C, "curl -L \"https://github.com$1\" 2>/dev/null|"; /(\/docker.*?\/download\/v.*?\/)/; $a=$1; 
            while(<C>){ s|.*?\*(docker.*)|https://github.com/$a/$1|; print }}' \
        | grep wincred | xargs -i curl -L {} -o "$DOCKERCRED" 2>/dev/null;
}

RESTART=false

havepkg docker.io && {
    echo "Uninstalling docker-io..."
    sudo apt -y remove docker docker-engine docker.io containerd runc
}

havepkg docker-ce || {
    echo "Installing docker-ce..."
    sudo apt update
    sudo apt install -y ca-certificates curl gnupg lsb-release
    sudo mkdir -p /etc/apt/keyrings

    curl -fsSL https://download.docker.com/linux/${DISTRO}/gpg \
        | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DISTRO} \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo usermod -a -G docker $USER
}

cat ~/.docker/config.json | contains 'credStore.*wincred' || {
    echo "Setting up credential store..."
    echo -e "{\n  \"credStore\": \"wincred\"\n}" > ~/.docker/config.json
    RESTART=true
}

# =======================================================================================================================
echo "Setting up neccessary or useful windows tool wrappers..."
WSL=$(wintool wsl.exe)
installed wsl                       || mkwrapper wsl                       "$WSL"
installed powershell                || mkwrapper powershell                "$POWERSHELL"
installed git-credential-manager    || mkwrapper git-credential-manager    "$GITCREDMGR"
installed docker-credential-wincred || mkwrapper docker-credential-wincred "$DOCKERCRED"
installed winget                    || mkwrapper winget                    "$WINGET"
installed choco                     || mkwrapper choco                     "$(wintool choco)"
installed shutdown                  || mkwrapper shutdown                  "$(wintool shutdown)"

# =======================================================================================================================
$RESTART && {
    echo "Going to shutdown $WSL_DISTRO_NAME in 5 seconds... Please restart manually..."
    echo "After restart do: docker login registry.your.local.one"
    for i in {1..5}; do sleep 1; echo -n . ; done
    echo "Bye ;-)"

    $WSL --terminate $WSL_DISTRO_NAME
}
