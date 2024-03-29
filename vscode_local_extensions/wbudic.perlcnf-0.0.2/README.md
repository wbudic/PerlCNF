## PerlCNF MS Visual Studio Code Extension

This is the extension that formats PerlCNF files that have the cnf Extension.  
It is recommended to start vscode to view and work with CNF from a fresh and local extensions directory.  
From the command line in the PerlCNF project directory type:

```plaintext
   code --extensions-dir ./vscode_local_extensions/
```

* You will need then to install the following extensions:
    * Perl Language Server (PLS) - Fractalboy
    * Perl - Language Debugger - Gerald Richter
    * Perl Navigator - bscan
    * Better Perl Syntax - Jeff Hykin

When you open some **CNF** file, then you might need to associate it with the new format.  
This is done with Select Language Mode (`Ctrl+K M` on Windows and Linux),  
or click on the file type in the editors footer.

Then type **PerlCNF**, if it doesn't appear, it means something went wrong starting or locating the extension.

## Manually Installing For VSCODE Default Workspace

It is not recommended to install it there (~/.vscode/extension).  
You will need to copy this directory wbudic.perlcnf-0.0.2 there and possibly modify ~/.vscode/extensions/extensions.json file.  
If installing first time open vscode in plain normal way, user workspace. And then copy over so it can auto detect it, then refresh extension.
Assign the cnf file extension to PerlCNF, if vscode hasn't done that for you.
vscode can reject it otherwise or if have a previous version.
To have it included it as an entry, i.e.:

```plaintext

   {
        "identifier": {
            "id": "wbudic.perlcnf"
        },
        "version": "0.0.2",
        "location": {
            "$mid": 1,
            "path": "~/.vscode/extensions/wbudic.perlcnf-0.0.2",
            "scheme": "file"
        },
        "relativeLocation": "wbudic.perlcnf-0.0.2"
    },

```

## Working with Markdown

You can author your README using Visual Studio Code. Here are some useful editor keyboard shortcuts:

* Split the editor (`Cmd+\` on macOS or `Ctrl+\` on Windows and Linux).
* Toggle preview (`Shift+Cmd+V` on macOS or `Shift+Ctrl+V` on Windows and Linux).
* Press `Ctrl+Space` (Windows, Linux, macOS) to see a list of Markdown snippets.

## For more information

* [Visual Studio Code's Markdown Support](http://code.visualstudio.com/docs/languages/markdown)
* [Markdown Syntax Reference](https://help.github.com/articles/markdown-basics/)

**Enjoy!**