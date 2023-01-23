# wsl-convenience

Just started using WSL2 the first time coming from linux. Some minor issues triggered me to create some minor helper functions to enhance the convenience working in the shell.
By the way PowerShell seems quite cool although I'm living in the bash most of the time.
Nevertheless the integration of WSL in windows is well accomplished.

## Setting up a basic development environment

Actually everybody has other needs. The very basic tools and functionality I need before I even start coding include:

* working installations of  `docker` and `git`
* new shell tabs opening in the same path as the tab I'm coming from
* my `.inputrc` and auto-completion
* the possibility to share data between different WSL distros
* a simple way to see what distro I'm currently using (some hint in the title of the terminal)

After searching around I figured out how to achieve all of these features.
As I'm lazy I've created a script that helps me setting up a distro in a reproducable way.

## bashrc functions: wsl-which

As the windows paths slow down extremly the autocompletion of bash, I decided to remove them.
But I still wanted to use windows tools directly from bash.
What is `command` or `which` under windows? ;-)

After playing around with `pwsh` I've built `wsl-which` which can help to search windows tools and create wrapper functions or aliases in bash.
Here we go.

```[bash]
user@wsl:~$ wsl-which '(wt|wsl)'   # actually its a grep -E 'regexp'
/mnt/c/Users/WSLUSER/AppData/Local/Microsoft/WindowsApps/wsl.exe
/mnt/c/Users/WSLUSER/AppData/Local/Microsoft/WindowsApps/wslconfig.exe
/mnt/c/Users/WSLUSER/AppData/Local/Microsoft/WindowsApps/wslg.exe
/mnt/c/Users/WSLUSER/AppData/Local/Microsoft/WindowsApps/wt.exe
/mnt/c/Windows/system32/wsl.exe
/mnt/c/Windows/system32/wslg.exe
```

As searching the path takes some time the results are temporarly cached under `/tmp/wsl-which.db`. 
Maybe I should move this to some more persistent place as `.local/share`.

To rebuild the cache, either remove the file or simply call `wsl-which [-u|--update]`.

## bashrc functions: to-alias

Another quite helpful bash function you'll find in your `.bashrc` after calling the installer is `to-alias`.
When piping to this function it creates either an alias or a wrapper function in your `.bash_aliases`.
The reason for wrapper functions is that not all "executable" files under windows can be called directly from the bash.
Thus they are passed to the powershell.

Here an example:

```[bash]
user@wsl:~$ wsl-which '(appwiz.cpl|pwsh.exe)' | to-alias
alias pwsh="/mnt/c/Program\ Files/PowerShell/7/pwsh.exe"            # added by "to-alias"
appwiz () { pwsh -c "& 'C:/Windows/System32/appwiz.cpl' $@"; }      # added by "to-alias"
```
