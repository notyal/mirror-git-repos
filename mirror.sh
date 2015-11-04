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
	local errorMsg="$1"

	if [[ -n "$errorMsg" ]]; then
		>&2 echo "Error: $errorMsg"
	else
		>&2 echo "Error: Unknown exception."
	fi

	exit 1
}

not_implemented(){
	>&2 echo "Error: This feature is currently not implemented."
	exit 1
}

print_help(){
	local program="$1"
	cat <<EOF
mirror.sh: Keep a set of git mirrors up to date.
Copyright (c) 2015 Layton Nelson <notyal.dev@gmail.com>

USAGE: $program [OPTION]...

OPTIONS:
  archive             Archive the repos.
  create <url>        Add a repo to the mirror directory.
  delete <repo>       Remove a repo from the mirror directory.
  list                List mirrors in the mirror directory.
    -a, --absolute    Show the absolute path for the location of each mirror.
  path                Show the mirror directory location.
  update              Update the list of mirrors in the mirror directory.
  query <user>        Query the Github API for a list of repos associated with
                      the provided user.
  help                Show this help.
EOF
	exit 0
}

find_mirrors(){
	cd "$DIR" || catch_failure
	find ./* -type d -name '*.git' || catch_failure "$ERROR_nogitrepos"
}

list_mirrors(){
	REPOLIST=$(find_mirrors)

	# parse arguments
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

query_github_repos(){
	local githubUser=$1
	local repoURL="https://api.github.com/users/$githubUser/repos"

	# check for argument
	if [[ -z "$githubUser" ]]; then
		catch_failure "No user was provided."
		exit 1
	fi

	# retrieve api token for github
	if [[ -f "$DIR/gh_token" ]]; then
		>&2 echo "Using Github API token from 'gh_token' local file..."
		GITHUB_API_TOKEN=$(<"$DIR"/gh_token)
	else
		local github_user=$(git config --get github.user)
		local github_token=$(git config --get github.token)

		if [[ ! -z "$github_user" && ! -z "$github_token" ]]; then
			>&2 echo "Using Github API token from Git config..."
			GITHUB_API_TOKEN="${github_user}:${github_token}"
		fi
	fi

	# fetch from github api
	if [[ -z "$GITHUB_API_TOKEN" ]]; then
		repoData="$(curl -s -w "%%HTTP=%{http_code}" $repoURL)"
	else
		repoData="$(curl -s -w "%%HTTP=%{http_code}" -u $GITHUB_API_TOKEN $repoURL)"
	fi

	# parse from fetched data
	local http_code=$(expr match "$repoData" '.*%HTTP=\([0-9]*\)')

	if [[ $http_code == 200 ]]; then
		sed -n 's/.*"clone_url": "\(.*\)".*/\1/p' <<< "$repoData"
	else
		catch_failure "Got HTTP error '$http_code' when trying to fetch from Github API."
		return 1
	fi

	unset repoData
}

update_mirrors(){
	echo "@ Looking for repos in directory: '$DIR'..."
	cd "$DIR" || catch_failure
	echo

	for repo in $(find_mirrors); do
		echo "@ Found repo: '$repo'."
		cd "$repo" || catch_failure "$ERROR_cannotcdrepo '$repo'."
		echo

		echo "@ Updating repo from remote..."
		git remote update || >&2 echo "$WARN_CannotUpdateRemote"
		echo

		# TODO: Archive this repo
		#archive_repo
		#echo

		# done with this repo, go back to top directory
		echo "\$ Done with '$repo'."
		echo "$HLINE"
		cd "$DIR" || catch_failure
		echo
	done
}

# archive_repo(){
# 	cd "$DIR" || catch_failure
# 				# TODO: Write method to archive the repos into a top dir.
# 				#
# 				#       Also, create a configuration file to store the current
# 				#       date of the repo, so the archives will only be created
# 				#       if the repo hasn't been updated by the remote.
# 				#
# 				#       Tar+gz the files into a central backup directory, next
# 				#       to the individual configuration files.
#
# 	#echo "# DEBUG: repo is: '$repo' or '${repo##*/}'."
# 	#echo "# DEBUG: current dir is: '$PWD' or '${PWD##*/}'."
#
# 	echo "@ Archiving current repo..."
# 	cd ..
# 	#tar -cvpzf
# }

create_repo(){
	local URL="$1"

	cd "$DIR" || catch_failure

	# split url into parts
	URL_ARRAY=($(awk -F/ '{for(i=3;i<=NF;i++) printf "%s\t",$i}' <<< "$URL"))

	# put the repo folder into its own variable
	REPO_FOLDER="${URL_ARRAY[@]:(-1)}"

	# make sure REPO_FOLDER ends in ".git"
	EXT=$(awk -F . '{if (NF>1) {print $NF}}' <<< "$REPO_FOLDER")

	# add ".git" if needed
	[[ ! "$EXT" = "git" ]] && REPO_FOLDER="${REPO_FOLDER}.git"

	# remove repo folder from the array
	unset URL_ARRAY[${#URL_ARRAY[@]}-1]

	echo "@ Creating repo for \"$1\"..."

	# basically, mkdir -p DOMAIN/DIR for repo url
	for folder in ${URL_ARRAY[@]}; do
		if [[ ! -d "$folder" ]]; then
			echo "@ Creating folder: '$folder' ..."
			mkdir "$folder" || catch_failure
		fi
		cd "$folder" || catch_failure
	done
	echo

	echo "@ Cloning repo for \"$1\"..."
	git clone --mirror "$URL" "$REPO_FOLDER" || catch_failure
	cd "$REPO_FOLDER" || catch_failure
	echo

	echo "@ Running git-gc to save space..."
	git gc
	echo

	# done with this repo, go back to top directory
	echo "\$ Done with '$REPO_FOLDER."
	echo "$HLINE"
	cd "$DIR" || catch_failure
}

# main()
case $1 in
	archive|-a|--archive|-archive ) not_implemented       ;; #archive_repo
	create |-c|--create |-create  ) create_repo "$2"      ;;
	delete |-d|--delete |-delete  ) not_implemented       ;; #delete_repo
	list   |-l|--list   |-list    ) list_mirrors $2       ;;
	path   |-p|--path   |-path    ) echo "$DIR"           ;;
	update |-u|--update |-update  ) update_mirrors        ;;
	query  |-q|--query  |-query   ) query_github_repos $2 ;;
	help   |-h|--help   |-help |* ) print_help "$0"       ;;
esac
exit
