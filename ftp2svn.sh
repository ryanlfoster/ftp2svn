#!/bin/bash

# check for svn and lftp
type -P svn &>/dev/null || { echo "Subversion (svn) is required but does not appear to be installed. Aborting." >&2; exit 1; }
type -P lftp &>/dev/null || { echo "LFTP (lftp), FTP client, is required but does not appear to be installed. Aborting." >&2; exit 1; }
type -P xpath &>/dev/null || { echo "xpath, is required but does not appear to be installed. Aborting." >&2; exit 1; }

# set up ftp2svn defaults
CONFIG_DIR=$HOME"/.ftp2svn"
CONFIG_FILE=$CONFIG_DIR"/main.conf"
LOG_FILE=/tmp/ftp2svn.log
PARA_NUM=5

## CONFIG CHECK ---------------------------------------------------------------

# check for config director existence - make it if it's not here.
if [ ! -d "$CONFIG_DIR" ]; then
	mkdir $CONFIG_DIR
fi

if [ -f "$CONFIG_FILE" ]; then
	if [ ! -r "$CONFIG_FILE" ]; then
		echo "Config file at "$CONFIG_FILE" is not readable. Please fix and re-run" >&2; exit 1;
	fi
else
	# no config file - dump the default and tell the user to prepare.
	cat > "$CONFIG_FILE" << EOF
## ftp2svn config file
## please edit as required

# the name of the repository folder inside your site archives
REPO_FOLDER_NAME="repository"

# the name of the mirror folder inside your site archives
MIRROR_FOLDER_NAME="mirror"

## END config
EOF
	cat > "$CONFIG_DIR""/site.conf.example" << EOF
## ftp2svn site configuration example
## please edit as required
## create a copy of this file for each site to be archived

# details for where the site is located to be backed up
FTP_ADDRESS="ftp://example.com"
FTP_USER="example"
FTP_PASSWORD="dotcom"

# the folder that should be mirrored and archived
FTP_FOLDER="/public_html"

# local details for the archive - relative to your home
ARCHIVE_LOCATION="ftp2svn/example"

## END config
EOF
	echo "[INFO] New config files created in '"$CONFIG_DIR"'."
	echo "Please edit as required and re-run this script with '--build' to set up the"
	echo "archive folders."
	exit 0;
fi

# might not even need these config settings
source "$CONFIG_FILE"

## GET ALL SITES --------------------------------------------------------------

if [ "$1" = "--build" ]; then
	echo ""
	echo "Building and checking ftp2svn folders and repositories."
	echo ""
	
	for file in $( find $CONFIG_DIR -type f -name '*.site.conf' )
	do
		echo "Loading '"$file"'"

		source "$file"

		# build params
		ARCHIVE=$HOME"/"$ARCHIVE_LOCATION
		ARCHIVE_REPO=$ARCHIVE"/"$REPO_FOLDER_NAME
		ARCHIVE_MIRROR=$ARCHIVE"/"$MIRROR_FOLDER_NAME



		## ---------------------------------------------- BUILDING CODE

		# build the main folder for this site...
		if [ ! -d "$ARCHIVE" ]; then
			echo "[ACTION] Making '"$ARCHIVE"'... "
			mkdir -p $ARCHIVE
		else
			echo "[INFO] Found archive folder : '"$ARCHIVE"'"
		fi

		# check that the mirror folder is a check-out of a repository
		# if it is, then we can assume the repo exists - this allows you to create
		# your own repo wherever you want.

		if [ ! -d "$ARCHIVE_MIRROR/.svn" ]; then

			if [ ! -d "$ARCHIVE_MIRROR" ]; then

				cd $ARCHIVE

				# drop in subversion
				if [ ! -d "$ARCHIVE_REPO" ]; then
					echo "[ACTION] Building Subversion repository at '"$ARCHIVE_REPO"'"
					svnadmin create $REPO_FOLDER_NAME
				else
					echo "[INFO] Found repository folder : '"$ARCHIVE_REPO"'"
				fi

				echo "[ACTION] Checking out repository into '"$ARCHIVE_MIRROR"'"
				svn co file://$ARCHIVE_REPO $ARCHIVE_MIRROR

				echo "[ACTION] Making trunk, branches and tags structure."
				cd $ARCHIVE_MIRROR
				mkdir trunk branches tags
				svn add trunk branches tags
				svn commit -m "initial commit"
			else
				echo "[ERROR] *** "$ARCHIVE_REPO" exists."
				echo "        *** but does not appear to be a valid repository."
				echo "...continuing checks"
			fi

		else
			echo "[INFO] Found mirror folder: '"$ARCHIVE_MIRROR"'"
			echo "[INFO] Mirror appears to be valid repository."
		fi

		# check ftp
		if lftp -c "open $FTP_ADDRESS & user $FTP_USER $FTP_PASSWORD & cd $FTP_FOLDER"
		then
			echo "[INFO] FTP credentials are correct."

			# make the lftp file with instructions...
       			echo "[INFO] Writing LFTP command file: '"$file.lftp"'"
			cat > "$file.lftp" << EOF
set ftp:list-options -a
set cmd:fail-exit true
open $FTP_ADDRESS -u $FTP_USER,$FTP_PASSWORD
lcd $ARCHIVE_MIRROR/trunk
mirror -c -e -x "\.svn\/" $FTP_FOLDER $FTP_FOLDER --parallel=$PARA_NUM --log=$LOG_FILE
close
EOF
		else
			echo "[ERROR] *** FTP credentials are not working."
		fi

		echo "Checks complete for this site."
		echo ""

	done

	echo "Finished build and check."
	echo "Now run 'ftp2svn.sh' to archive."
	echo ""
	
	exit 0

else
	echo "= Running ftp2svn in normal mode"

	for file in $( find $CONFIG_DIR -type f -name '*.site.conf' )
	do
		echo "Loading '"$file"'"

                source "$file"

                # build params
                ARCHIVE=$HOME"/"$ARCHIVE_LOCATION
                ARCHIVE_MIRROR=$ARCHIVE"/"$MIRROR_FOLDER_NAME
		LFTP_COMMS="$file.lftp"

		if [ -f "$LFTP_COMMS" ]
		then
        		if [ ! -r "$LFTP_COMMS" ]
			then
                		echo "[ERROR] LFTP command file at "$LFTP_COMMS" is not readable."
				echo "*** Please fix and re-run."
				exit 1
			fi
			# fall through - file is readable and exists.
		else
			echo "[ERROR] LFTP command file does not exist yet."
			echo "*** Please run again with '--build' to create settings."
			exit 1
		fi

		### ------------- MIRRORING ----------------------###
		echo "`date "+%F %T"` = Doing mirroring..."
		if [ -f "$LOG_FILE" ]
		then
			rm "$LOG_FILE"
		fi
		lftp -f "$file.lftp"
		cat "$LOG_FILE"
	
		echo "Done FTP."
		echo ""

		### ------------- SVN WORK  ----------------------###
		echo "`date "+%F %T"` = Doing subversion work..."
		cd "$ARCHIVE_MIRROR"

		# add new files
		svn stat --xml | xpath -q -e "/status/target/entry[wc-status/@item='unversioned']/@path" | sed -e 's/ path=/svn add /' | sh 2>&1

		# remove old files
		svn stat --xml | xpath -q -e "/status/target/entry[wc-status/@item='missing']/@path" | sed -e 's/ path=/svn del /' | sh 2>&1

		# do commit
		svn commit --non-interactive -m "auto-commit from script" 2>&1

		echo "All done."
		echo ""

	done
	
	echo "ftp2svn work complete."
fi

exit 0
