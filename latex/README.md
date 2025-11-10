# Global Custom LaTeX Macro Files, Locally

This directory contains my LaTeX macros, which, by the method outlined at the root of this repository, are symlinked to `~/texmf/tex/latex`, the standard location to put such things after a fresh install of [TeX Live](https://www.tug.org/texlive/). This method keeps things much cleaner than the method I used to use, which is outlined below.

Below the double line are the old [instructions](#instructions-old) for getting global LaTeX macro files set up locally on Unix-like machines in arbitrary locations on your system.  It's kind of an annoying setup, but it can be worth it for some people, for example who would like to store their macros on a flashdrive (like I used to do). These days AI can probably give you instructions, and answers to more questions, but when I was first figuring this out I could not find **simple** instructions that worked **every time** anywhere.


#### Why would you want to make use of these instructions?

It's a special kind of problem for people who write in LaTeX, **locally**, and have very long preambles. As of 2024, Overleaf does not support global custom macro files. This is the primary reason why I do not use Overleaf. At this point, even if they offer this as a feature, I think I'm pretty well dialed in.

But here's a scenario to help understand why this kind of thing might matter. For example, I am a logician, and working in LaTeX can be a bit cumbersome when the default names of the symbols I use often have little in common with the meaning they have in my writing, and can often be long and "out of the way" syntactically. Over time one redefines the symbols with a bit of flavor: for example, in my case, `\Vdash` gets redefined as `\trues`. Eventually there is a long list of these in the preamble of every document, which has to be copied over into each new document -- so one just offloads it all into a file, for example `logic.sty`, which you copy into each of your new projects. But eventually you have as many different `logic.sty` files as you have projects, each of which has some special commands defined in it and only it.

This is where these instructions (or using the Stow method I outline at the root of this repo) come in handy: they give you a way to have your custom LaTeX macro files stored in one place, so that you never go to use a command that's only defined in God-knows-which of your documents, only for it not to compile.

---
---

## Instructions (old)

I originally wrote myself these instructions years ago, so by now, obviously I am doing things differently. But I leave these here in case they're of interest to anyone.

These instructions are generalizable to different locations. For example:
  1. If you are happy with the default location, which is `~/texmf`, then you can ignore most of what follows, except the parts about adding the tree `~/texmf/tex/latex`.
  2. If you want to make it the location of a GitHub repository, which you can clone on different machines, you can move it where your other repos are and `git init` and go from there.

Below I provide the instructions on Linux machines; the procedure is similar on both Windows and Mac, but probably some of the locations are different.

1. Preliminary: Make sure you have [TeX Live](https://www.tug.org/texlive/) installed. As a rule, I avoid the distributions in the `apt` and `rpm` repositories, only because the `curl` version [here](https://www.tug.org/texlive/quickinstall.html) gets you `tlmgr` (the TeX Live package manager).

2. Create a folder called `texmf` where you would like your custom macro files to be stored. At one point mine was in the home directory of my USB stick, but now it's just on my desktop; your home directory is another common location. **The location of this folder cannot be changed without having to go through these steps again.** 
    - Inside `texmf`, create a folder called `tex`.
    - Inside `tex`, create a folder called `latex`.
    - Inside `latex`, create a folder for each of your macros, which has the same exact name as the primary file that will go in each folder, i.e., the exact name of the macro you intend to invoke in your preambles.
        - For example, if you have two macro files, they might be placed something like this:
            ```
            -texmf
              -tex
	            -latex
                  -logic
                    logic.sty
                  -tufte-compact
                    tufte-compact.cls
                    tufte-common.def
            ```

3. Find where your `texmf.cnf` file is. For example, you might search for "TEXMFHOME" in your filesystem:
    ```
    sudo find / -type f -exec grep -H 'TEXMFHOME' {} \;
    ```
    Running this command may take some time! In both Fedora and Ubuntu (Pop) it's at:  `/usr/share/texlive/texmf-dist/web2c/texmf.cnf`.
    >Note that, as of some time somewhat recently, the recommended path of the file you should edit is: `/usr/local/texlive/<year>/texmf.cnf`, where all you have to add is: `TEXMFHOME = /path/to/your/texmf`.
    
    On Windows and Mac, you'll have to search system-wide for your `texmf.cnf` file.

4. In your preferred editor, search for the line that contains `TEXMFHOME` (circa line 84 on Linux) and change the default location `~/texmf` to your desired location (you might need to be root):
    - Ubuntu (Pop):  `/media/bph/bph-work/texmf`
	- Fedora:  `/run/media/bph/bph-work/texmf`
    
    **Save the changes.**

5. Update the hash:
	- Ubuntu:  
        ```
        texhash /media/bph/bph-work/texmf
        ```
	- Fedora:
        ```
        texhash /run/media/bph/bph-work/texmf
        ```
    This will create a file inside the `texmf` folder called `ls-R` which directs the compiler to your custom macros.

And now you are set!  Just include your custom style in the preamble of your document (don't include the file extension), and any commands it includes will work:
```
\documentclass{article}
\usepackage{logic}
\begin{document}
```

### A Little Piece of Advice

If ever everything seems configured properly but your document isn't compiling, returning errors related to the style files, of course look for typos in the style file, but you might also try updating the hash.

