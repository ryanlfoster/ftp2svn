ftp2svn
=======

About
-----

This is a bash script for backing up any collection of files over FTP and saving the mirror to a Subversion repository.

More about the motivation is here : http://blog.jamescooke.info/post/836576107/ftp2svn-something-for-version-tracking-when

Quick start
-----------

* Make sure that you can install Subversion, LFTP and xpath in your command line, this script will use them all at some point. For Ubuntu users this will look like:
	$ sudo apt-get install subversion lftp libxml-xpath-perl
* Grab the `ftp2svn.sh` file and save it somewhere nice in your folders. The explanation below assumes that you've added it to your path.
* Make the script executable.
	$ chmod u+x ftp2svn.sh
* Perform the first execution of the script, this will build the `~/.ftp2svn` config folder.
	$ ftp2svn
* Now drop in to that folder and edit the example config file.
	$ cd ~/.ftp2svn
	$ mv example.site.conf yoursite.site.conf
	$ vi yoursite.site.conf
* Add your settings and save.
* Run the script with the '--build' flag. ftp2svn will test your settings, build initial repositories and create the lftp command files for each site if the FTP credentials give it access to the folder specified in the settings.
	$ ftp2svn --build
* Hopefully everything's worked out fine. You can now run the main command to complete your first download and checkout. You'll see lots of output as ftp2svn adds each file and commits the whole of your download to the repository.
* You can now add ftp2svn to your crontab to run regularly.

Notes
-----

* You can make as many `.site.conf` files as you have sites to backup, they can be added at any time ftp2svn isn't running and can be tested and installed with the '--build' flag.
* Currently this script is highly dependent on the subversion output of `svn stat`. If that format changes then it's likely this script will break - not something that's very good or desired, hopefully will update soon.
* If you want to archive the root of your FTP account, just leave the folder name blank in that site's config file.
* Multi folder archiving is coming soon.
* Beware that running `ftp2svn --build` rewrites the .site.conf.lftp instruction files to match the config files. This will be fixed to include a prompt in the build part of the script.

GPL
---

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

See http://www.gnu.org/licenses/gpl.html



