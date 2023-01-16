# wsl-convenience

Just started using WSL2 the first time coming from linux. Some minor issues triggered me to create some minor helper functions to enhance the convenience working in the shell. 
By the way PowerShell seems quite cool although I'm living in the bash most of the time.
Nevertheless the integration of WSL in windows is well accomplished. 

## bashrc functions: wsl-which
As the windows paths slow down extremly the autocompletion of bash, I decided to remove them. 
But I still wanted to use windows tools directly from bash. 
What is `command` or `which` under windows? ;-) 

After playing around with `pwsh` I've built `wsl-which` and `to-alias` which can help to search windows tools and create wrapper functions or aliases in bash. 
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
Next step. What about aliases? Executables can be easily aliased. 
But `.cmd, .com, .cpl, .msc, .ps1, .vbs, .wsf, ...` must wrapped in some way and be passed to the `pwsh` for further execution. 
That's what `to-alias` does: it creates aliases and wrapper functions and loads them into your current environment. 

Its results are appended at the end of `.bash_aliases`. 
In the following example I prefer my user specific installation. 
Thus I filter the `wsl-which` results before I pipe them to `to-alias`.

```[bash]
... TO BE CONTINUED ...
```
