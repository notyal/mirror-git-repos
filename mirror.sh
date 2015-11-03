#!/bin/bash
################################################################################
# Copyright (c) 2015 Layton Nelson <notyal.dev@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
################################################################################

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HLINE="----------------------------------------------------------------------"

# define failure messages:
WARN_CannotUpdateRemote="[WARN]: Could not run: 'git remote update'."
ERROR_nogitrepos="Cannot find any git repos in dir: '$DIR'."
ERROR_cannotcdrepo="Cannot enter directory for repo."

# functions:
catch_failure(){
	[ -n "$1" ] && >&2 echo "ERROR: $1"
	>&2 echo "Caught a failure."
	>&2 echo "Exiting..."
	exit 1
}

not_implemented(){
	>&2 echo "Error: This feature is currently not implemented."
	exit 1
}

print_help(){
	local program="$1"

	echo "mirror.sh: Keep a set of git mirrors up to date."
	echo "Copyright (c) 2015 Layton Nelson <notyal.dev@gmail.com>"
	echo
	echo "USAGE: $program [OPTION]..."
	echo
	echo "OPTIONS:"
	echo ">  archive             Archive the repos."
	echo ">  create <url>        Add a repo to the mirror directory."
	echo ">  delete <repo>       Remove a repo from the mirror directory."
	echo ">  list                List mirrors in the mirror directory."
	echo "     -a, --absolute    Show the absolute path for the location of each mirror."
	echo ">  path                Show the mirror directory location."
	echo ">  update              Update the list of mirrors in the mirror directory."
	exit 0
}

find_mirrors(){
	cd "$DIR" || catch_failure
	find ./* -type d -name '*.git' || catch_failure "$ERROR_nogitrepos"
}

list_mirrors(){
	REPOLIST=$(find_mirrors)

	case $1 in
		absolute|-a|--absolute|-absolute|abs|--abs|-abs)
			for repo in $REPOLIST; do
				cd "$DIR" || catch_failure
				cd "$repo" || catch_failure "$ERROR_cannotcdrepo"
				echo "$PWD"
			done
			;;
		*)
			for repo in $REPOLIST; do
				echo "$repo"
			done
			;;
	esac
}

update_mirrors(){
	echo "Looking for repos in directory: '$DIR'..."
	cd "$DIR" || catch_failure
	echo

	REPOLIST=$(find_mirrors)

	for repo in $REPOLIST; do
		echo ">>>>> Found repo: '$repo'."
		cd "$repo" || catch_failure "$ERROR_cannotcdrepo '$repo'."
		echo

		echo "( ) Updating repo from remote..."
		git remote update || >&2 echo "$WARN_CannotUpdateRemote"
		echo

		echo "( ) Running git-gc to save space..."
		git gc
		echo

		# TODO: Archive this repo
		#archive_repo
		#echo

		# done with this repo, go back to top directory
		echo "(*) Done with '$repo'."
		echo "$HLINE"
		cd "$DIR" || catch_failure
		echo
	done
}

archive_repo(){
	cd "$DIR" || catch_failure
				# TODO: Write method to archive the repos into a top dir.
				#
				#       Also, create a configuration file to store the current
				#       date of the repo, so the archives will only be created
				#       if the repo hasn't been updated by the remote.
				#
				#       Tar+gz the files into a central backup directory, next
				#       to the individual configuration files.

	#echo "# DEBUG: repo is: '$repo' or '${repo##*/}'."
	#echo "# DEBUG: current dir is: '$PWD' or '${PWD##*/}'."

	echo "( ) Archiving current repo..."
	cd ..
	#tar -cvpzf
}

create_repo(){
	cd "$DIR" || catch_failure
	URL="$1"

	# split url into parts
	URL_ARRAY=($(echo "$URL" | awk -F/ '{for(i=3;i<=NF;i++) printf "%s\t",$i}'))

	REPO_FOLDER="${URL_ARRAY[@]:(-1)}"  # put the repo folder into its own variable

	# make sure REPO_FOLDER ends in ".git"
	EXT=$(echo "$REPO_FOLDER" | awk -F . '{if (NF>1) {print $NF}}')

	# add ".git" if needed
	if [[ ! "$EXT" = "git" ]]; then
		REPO_FOLDER="${REPO_FOLDER}.git"
	fi

	unset URL_ARRAY[${#URL_ARRAY[@]}-1]  # remove repo folder from the array


	echo "( ) Creating repo for \"$1\"..."

	# basically, mkdir -p DOMAIN/DIR for repo url
	for folder in ${URL_ARRAY[@]}; do
		if [[ ! -d "$folder" ]]; then
			echo ">>>>> Creating folder: '$folder' ..."
			mkdir "$folder" || catch_failure
		fi
		cd "$folder" || catch_failure
	done
	echo

	echo "( ) Cloning repo for \"$1\"..."
	git clone --mirror "$URL" "$REPO_FOLDER" || catch_failure
	cd "$REPO_FOLDER" || catch_failure
	echo

	echo "( ) Running git-gc to save space..."
	git gc
	echo

	# done with this repo, go back to top directory
	echo "(*) Done with '$REPO_FOLDER."
	echo "$HLINE"
	cd "$DIR" || catch_failure
}

# main()
case $1 in
	archive|-a|--archive)
		not_implemented
		#archive_repo
		;;
	create|-c|--create|-create)
		create_repo "$2"
		;;
	delete|-d|--delete|-delete)
		not_implemented
		;;
	list|-l|--list|-list)
		list_mirrors $2
		;;
	path|-p|--path|-path)
		echo "$DIR"
		;;
	update|-u|--update|-update)
		update_mirrors
		;;
	help|-h|--help|-help|*)
		print_help "$0"
		;;
esac
exit
