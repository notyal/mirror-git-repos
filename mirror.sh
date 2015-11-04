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

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DIR="$SCRIPT_DIR/repos"

# enable colors
alias echo='echo -e'

# define literal colors:
c=$'\e[0m' # reset
cblk=$'\e[0;30m'
cred=$'\e[0;31m'
cgrn=$'\e[0;32m'
cylw=$'\e[0;33m'
cblu=$'\e[0;34m'
cpur=$'\e[0;35m'
ccyn=$'\e[0;36m'
cwht=$'\e[0;37m'

# colorscheme:
cWARN=$cylw
cERROR=$cred
cINFO=$cblu
cLINE=$cgrn
cMARK=$cpur
cDIR=$ccyn
cCMD=$cred

# define strings:
horizontal_line="${cLINE}----------------------------------------------------------------------${c}"
_m="${cMARK}@${c}"  # program output mark
_f="${cMARK}\$${c}" # program finished mark

# define messages:
WARN_cannot_update_remote="${cWARN}[WARN]: Could not run:${c} '${cCMD}git remote update${c}'${cWARN}.${c}"
ERROR_no_git_repos="${cWARN}Cannot find any git repos in dir${c}: '${cDIR}$DIR${c}'${cWARN}.${c}"
ERROR_cannot_cd_repo="${cERROR}Cannot enter directory for repo.${c}"

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

	local h=${cylw} # headings
	local o=${cblu} # options
	local a=${cred} # args
	local e=${cgrn} # extra args

	local i='' # fix indent/alignment

	cat <<EOF
mirror.sh: Keep a set of git mirrors up to date.
Copyright (c) 2015 Layton Nelson <notyal.dev@gmail.com>

${h}USAGE${c}: $program [${o}OPTION${c}]...

${h}OPTIONS${c}:
  ${o}archive${c} $i$i$i$i               Archive the repos.
  ${o}create${c} <${a}url${c}>           Add a repo to the mirror directory.
  ${o}backup-gh-user${c} <${a}user${c}>  Backup all repos associated with a user on Github.
  ${o}delete${c} <${a}repo${c}>          Remove a repo from the mirror directory.
  ${o}list${c}    $i$i$i$i               List mirrors in the mirror directory.
    -${e}a${c}, --${e}absolute${c}       Show the absolute path for the location of each mirror.
  ${o}path${c}    $i$i$i$i               Show the mirror directory location.
  ${o}update${c}  $i$i$i$i               Update the list of mirrors in the mirror directory.
  ${o}query${c} <${a}user${c}>           Query the Github API for a list of repos associated
                 $i$i$i$i$i$i$i$i        with the provided user.
  ${o}help${c}   $i$i$i$i                Show this help.
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
		-a|--absolute)
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
		>&2 echo "${cINFO}Using Github API token from${c} '${cDIR}gh_token${c}' ${cINFO}local file...${c}"
		github_api_token=$(<"$DIR"/gh_token)
	else
		local github_user=$(git config --get github.user)
		local github_token=$(git config --get github.token)

		if [[ ! -z "$github_user" && ! -z "$github_token" ]]; then
			>&2 echo "${cINFO}Using Github API token from Git config...${c}"
			github_api_token="${github_user}:${github_token}"
		fi
	fi

	# fetch from github api
	if [[ -z "$github_api_token" ]]; then
		repo_data="$(curl -s -w "%%HTTP=%{http_code}" $repo_url)"
	else
		repo_data="$(curl -s -w "%%HTTP=%{http_code}" -u $github_api_token $repo_url)"
	fi

	# parse from fetched data
	local http_code=$(expr match "$repo_data" '.*%HTTP=\([0-9]*\)')

	if [[ $http_code == 200 ]]; then
		sed -n 's/.*"clone_url": "\(.*\)".*/\1/p' <<< "$repo_data"
	else
		catch_failure "${cERROR}Got HTTP error${c} '${cINFO}$http_code${c}' ${cERROR}when trying to fetch from Github API.${c}"
		return 1
	fi

	unset repo_data
}

update_mirror_remote(){
	echo "${_m} ${cINFO}Updating repo from remote...${c}"
	git remote update || >&2 echo "$WARN_cannot_update_remote"
	echo
}

update_mirrors(){
	echo "${_m} ${cINFO}Looking for repos in directory${c}: '${cDIR}$DIR${c}'${cINFO}...${c}"
	cd "$DIR" || catch_failure
	echo

	for repo in $(find_mirrors); do
		echo "${_m} ${cINFO}Found repo${c}: '${cDIR}$repo${c}'${cINFO}.${c}"
		cd "$repo" || catch_failure "$ERROR_cannot_cd_repo '${cDIR}$repo${c}'."
		echo

		update_mirror_remote

		# TODO: Archive this repo
		#archive_repo
		#echo

		# done with this repo, go back to top directory
		echo "${_f} ${cINFO}Done with${c} '${cDIR}$repo${c}'${cINFO}.${c}"
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
# 	echo "${_m} ${cINFO}Archiving current repo...${c}"
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

	echo "${_m} ${cINFO}Creating repo for${c} '${cDIR}$1${c}'${cINFO}...${c}"

	# basically, mkdir -p DOMAIN/DIR for repo url
	for folder in ${url_array[@]}; do
		if [[ ! -d "$folder" ]]; then
			echo "${_m} ${cINFO}Creating folder${c}: '${cDIR}$folder${c}'${cINFO}...${c}"
			mkdir "$folder" || catch_failure
		fi
		cd "$folder" || catch_failure
	done
	echo

	if [[ ! -d "$repo_folder" ]]; then
		echo "${_m} Cloning repo for \"$1\"..."
		git clone --mirror "$repo_url" "$repo_folder" || catch_failure
		cd "$repo_folder" || catch_failure
		echo

echo "${_m} ${cINFO}Running git-gc to save space...${c}"
		git gc
		echo
	else
		echo "${cWARN}NOTE: Repo has already been cloned or the folder already exists...${c}"
		echo
		update_mirror_remote
	fi

	# done with this repo, go back to top directory
	echo "${_f} ${cINFO}Done with${c} '${cDIR}$repo_folder'${cDIR}.${c}"
	echo "$horizontal_line"
	cd "$DIR" || catch_failure
}

backup_gh_user(){
	local github_user=$1
	if [[ -z "$github_user" ]]; then
		catch_failure "No user was provided."
		exit 1
	fi

	echo "@ Cloning all repos from Github user: $github_user"
	for github_repo in $(query_github_repos $github_user); do
		create_repo "$github_repo"
	done
}

# main()
case $1 in
	archive        |-a   ) not_implemented       ;; #archive_repo
	create         |-c   ) create_repo "$2"      ;;
	backup-gh-user |-b   ) backup_gh_user "$2"   ;;
	delete         |-d   ) not_implemented       ;; #delete_repo
	list           |-l   ) list_mirrors $2       ;;
	path           |-p   ) echo "$DIR"           ;;
	update         |-u   ) update_mirrors        ;;
	query          |-q   ) query_github_repos $2 ;;
	help           |-h |*) print_help "$0"       ;;
esac
exit
