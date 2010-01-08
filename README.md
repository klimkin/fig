Description
===========

Fig is a utility for configuring environments and managing dependencies across a team of developers. You give it a list of packages and a shell command to run; it creates an environment that includes those packages, then executes the shell command in it (the caller's environment is not affected). 

An "environment" in fig is just a set of environment variables. A "package" is a collection of files, plus some metadata describing what environment variables should be modified when the package is included. 

Developers can a use package files to specify the list of dependencies to use for different tasks. This file will typically be versioned along with the rest of the source files. This ensures that all developers on a team are using the same environemnts. 

Packages exist in two places: a "local" repository in the user's home directory, and a "remote" repository on a server somewhere that is shared by a team. Fig will automatically download packages from the remote repository and install them in the local repository, when needed. 

Fig is similar to a lot of other package/dependnency managment tools. In particular, it steals a lot of ideas from Apache Ivy and Debian APT. However, unlike Ivy, fig is meant to be lightweight (no XML, no JVM startup time), language agnostic (Java doesn't get preferential treatment), and work with executables as well as libraries. And unlike APT, fig is meant to be cross platform (Windows support is coming) and project-oriented.

Installation
============

Fig can be installed via rubygems. The gems are hosted at [Gemcutter](http://gemcutter.org), so you'll need to set that up first:

    $ gem install gemcutter
    $ gem tumble

Then you can install fig:

     $ gem install fig

Usage
=====

Fig recognizes the following options (not all are implemented yet):

### Flags ###

    -d, --debug   Print debug info
        --force   Download/install packages from remote repository, even if up-to-date
    -u, --update  Download/install packages from remote repository, if out-of-date
    -n, --no      Automatically answer "n" for any prompt (batch mode)
    -y, --yes     Automatically answer "y" for any prompt (batch mode)


### Environment Modifiers ###

The following otpions modify the environment generated by fig:

    -i, --include DESCRIPTOR  Include package in environment (recursive)
    -p, --append  VAR=VALUE   Append value to environment variable using platform-specific separator
    -s, --set     VAR=VALUE   Set environment variable

### Environment Commands ###

The following commands will be run in the environment created by fig:

    -b, --bash                Print bash commands so user's environment can be updated (usually used with 'eval')
    -g, --get     VARIABLE    Get value of environment variable
    -x, --execute DESCRIPTOR  Execute command associated with specified configuration

    -- COMMAND [ARGS...]      Execute arbitrary shell command

### Other Commands ###

Fig also supports the following options, which don't require a fig environment. Any modifiers will be ignored:

    -?, -h, --help   Display this help text
    --publish        Upload package to the remote repository (also installs in local repository)
    --publish-local  Install package in local repository only
    --list           List the packages installed in local repository   

Examples
========

Fig lets you configure environments three different ways:

* From the command line
* From a "package.fig" file in the current directory
* From packages included indirectly via one of the previous two methods

### Command Line ###

So to get started, let's trying defining an environment variable via the command line and executing a command in the newenvironment. We'll set the "GREETING" variable to "Hello", then run a command that uses that variable:

    $ fig -s GREETING=Hello -- echo "\$GREETING, World"
    Hello, World

Note that you need to put a slash before the dollar sign, otherwise the shell will evaluate the environment variable before it ever gets to fig.

Also note that when running fig, the original environment isn't affected:

     $ echo $GREETING
     <nothing>

Fig also lets you append environment variables, using the system-specified path separator (e.g. colon on unix, semicolon on windows). This is useful for adding directories to the PATH, LD_LIBRARY_PATH, CLASSPATH, etc. For example, let's create a "bin" directory, add a shell script to it, then include it in the PATH:

    $ mkdir bin
    $ echo "echo \$GREETING, World" > bin/hello
    $ chmod +x bin/hello
    $ fig -s GREETING=Hello -p bin -- hello
    Hello, World

### Fig Files ###

You can also specify environment modifiers in files. Fig looks for a file called "package.fig" in the current directory, and automatically processes it. So we can implement the previous example by creating a "package.fig" file that looks like:
        
    config default
      set GREETING=Hello
      append PATH=@/bin
    end
    
The '@' symbol represents the directory that the "package.fig" file is in (this example would still work if we just used "bin", but later on when we publish our project to the shared repository we'll definitely need the '@'). Then we can just run:

    $ fig -- hello
    Hello, World

A single fig file can have multiple configurations:

    config default 
      set GREETING=Hello
      append PATH=@/bin
    end

    config french
      set GREETING=Bonjour
      append PATH=@/bin
    end

Configurations other than "default" can be specified using the "-c" option:

    $ fig -c french -- hello
    Bonjour, World
     
### Packages ###

Now let's say we want to share our little script with the rest of the team by bundling it into a package. The first thing we need to do is specify the location of the remote repository by defining the FIG_REMOTE_URL environment variable. If you just want to play around with fig, you can have it point to localhost:

   $ export FIG_REMOTE_URL=ssh://localhost`pwd`/remote

Before we publish our package, we'll need to tell fig which files we want to include. We do this by using the "resource" statement in our "package.fig" file:

    resource bin/hello

    config default...

Now we can share the package with the rest of the team by using the "--publish" option:

    $ fig --publish hello/1.0.0

The "hello/1.0.0" string represents the name of the package and the version number. Once the package has been published, we can include it in other environments by using the "-i" or "--include" option (I'm going to move the "package.fig" file out of the way first, so that fig doesn't automatically process it.):

    $ mv package.fig package.bak
    $ fig -u -i hello/1.0.0 -- hello
    ...downloading files...
    Hello, World
		
The "-u" (or "--update") option tells fig to check the remote repository for packages if they aren't already installed locally (fig will never make any network connections unless this option is specified). Once the packages are downloaded, we can run the same command without the "-u" option:

    $ fig -i hello/1.0.0 -- hello
    Hello, World

Also, when including a package, you can specify a particular configuration by appending it to the package name using a colon:

    $ fig -i hello/1.0.0:french -- hello
    Hello, World

### Retrieves ###

By default, the resources associated with a package live in the fig home directory, which defaults to "~/.fighome". This doesn't always play nicely with IDE's however, so fig gives you a way to copy resources from the repository to the current directory. To do this you add "retrieve" statements to your "package.fig" file.

For example, let's create a package that contains a library for the "foo" programming language. First we'll define a "package.fig" file:

    config default
      append FOOPATH=lib/hello.foo
    end

Then:

    $ mkdir lib
    $ echo "print 'hello'" > lib/hello.foo
    $ fig --publish hello-lib/3.2.1    

Now we'll move to a different directory (or delete the current "package.fig" file) and create a new "package.fig" file:

    retrieve FOOPATH->lib/[package]
    config default
      include hello-lib/3.2.1
    end

When we do an update, all resources in the FOOPATH will be copied into the lib directory, into a subdirectory that matches the package name:

     $ fig -u
     ...downloading...
     ...retrieving...
     $ cat lib/hello-lib/hello.foo
     print 'hello'

Community
=========

\#fig on irc.freenode.net

[Fig Mailing List](http://groups.google.com/group/fig-user)

Copyright
=========

Copyright (c) 2009 Matthew Foemmel. See LICENSE for details.
