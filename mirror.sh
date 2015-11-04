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
horizontal_line="----------------------------------------------------------------------"

# define failure messages:
WARN_cannot_update_remote="[WARN]: Could not run: 'git remote update'."
ERROR_no_git_repos="Cannot find any git repos in dir: '$DIR'."
ERROR_cannot_cd_repo="Cannot enter directory for repo."

# functions:
catch_failure(){
	local error_msg="$1"

	if [[ -n "$error_msg" ]]; then
		>&2 echo "Error: $error_msg"
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
	find ./* -type d -name '*.git' || catch_failure "$ERROR_no_git_repos"
}

list_mirrors(){
	repo_list=$(find_mirrors)

	# parse arguments
	case $1 in
		absolute|-a|--absolute|-absolute|abs|--abs|-abs)
			for repo in $repo_list; do
				cd "$DIR" || catch_failure
				cd "$repo" || catch_failure "$ERROR_cannot_cd_repo"
				echo "$PWD"
			done
			;;
		*)
			for repo in $repo_list; do
				echo "$repo"
			done
			;;
	esac
}

query_github_repos(){
	local github_user=$1
	local repo_url="https://api.github.com/users/$github_user/repos"

	# check for argument
	if [[ -z "$github_user" ]]; then
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
		repo_data="$(curl -s -w "%%HTTP=%{http_code}" $repo_url)"
	else
		repo_data="$(curl -s -w "%%HTTP=%{http_code}" -u $GITHUB_API_TOKEN $repo_url)"
	fi

	# parse from fetched data
	local http_code=$(expr match "$repo_data" '.*%HTTP=\([0-9]*\)')

	if [[ $http_code == 200 ]]; then
		sed -n 's/.*"clone_url": "\(.*\)".*/\1/p' <<< "$repo_data"
	else
		catch_failure "Got HTTP error '$http_code' when trying to fetch from Github API."
		return 1
	fi

	unset repo_data
}

update_mirrors(){
	echo "@ Looking for repos in directory: '$DIR'..."
	cd "$DIR" || catch_failure
	echo

	for repo in $(find_mirrors); do
		echo "@ Found repo: '$repo'."
		cd "$repo" || catch_failure "$ERROR_cannot_cd_repo '$repo'."
		echo

		echo "@ Updating repo from remote..."
		git remote update || >&2 echo "$WARN_cannot_update_remote"
		echo

		# TODO: Archive this repo
		#archive_repo
		#echo

		# done with this repo, go back to top directory
		echo "\$ Done with '$repo'."
		echo "$horizontal_line"
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
	local repo_url="$1"

	cd "$DIR" || catch_failure

	# split url into parts
	url_array=($(awk -F/ '{for(i=3;i<=NF;i++) printf "%s\t",$i}' <<< "$repo_url"))

	# put the repo folder into its own variable
	repo_folder="${url_array[@]:(-1)}"

	# make sure repo_folder ends in ".git"
	repo_folder_ext=$(awk -F . '{if (NF>1) {print $NF}}' <<< "$repo_folder")

	# add ".git" if needed
	[[ ! "$repo_folder_ext" = "git" ]] && repo_folder="${repo_folder}.git"

	# remove repo folder from the array
	unset url_array[${#url_array[@]}-1]

	echo "@ Creating repo for \"$1\"..."

	# basically, mkdir -p DOMAIN/DIR for repo url
	for folder in ${url_array[@]}; do
		if [[ ! -d "$folder" ]]; then
			echo "@ Creating folder: '$folder' ..."
			mkdir "$folder" || catch_failure
		fi
		cd "$folder" || catch_failure
	done
	echo

	echo "@ Cloning repo for \"$1\"..."
	git clone --mirror "$repo_url" "$repo_folder" || catch_failure
	cd "$repo_folder" || catch_failure
	echo

	echo "@ Running git-gc to save space..."
	git gc
	echo

	# done with this repo, go back to top directory
	echo "\$ Done with '$repo_folder."
	echo "$horizontal_line"
	cd "$DIR" || catch_failure
}

create_from_gh(){
	local github_user=$1
	if [[ -z "$github_user" ]]; then
		catch_failure "No user was provided."
		exit 1
	fi

	for i in $(query_github_repos $github_user); do
		echo "GOT: '$i'."
	done
}

# main()
case $1 in
	test   |-t                    ) create_from_gh        ;;
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
