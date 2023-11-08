#!/bin/bash

VER=2023-04-18

. $(dirname $0)/init-functions

_temp_fixes_=$(mktemp)
_all_log_fixes=$(mktemp)

# cleanup jobs
trap '[ -n "$(jobs -pr)" ] && kill $(jobs -pr)' INT QUIT TERM EXIT

# check git install
function check_git_is_installed()
{
	command -v git &> /dev/null
	[ $? -ne 0 ] && echo -e "${RED}please install git first${RC}" && exit 1;
}

# check git-repo
function is_git_repository()
{
	[ -d .git ] || git rev-parse --git-dir > /dev/null 2>&1
	[ $? -ne 0 ] && echo -e "${RED}This directory is not a git repository.${RC}" && exit 1
}

# search fixes-message
function search_fixes()
{
	origial=$1
	commit_12=${origial:0:12}
	gitData=`git show -s --date=format:'%d-%m-%Y' --format=%cd $commit_12`
	commit=${origial:0:10}
	git --no-pager log --after $gitData --grep "^Fixes:\s.*${commit}" --pretty="%h" origin/master >> ${_temp_fixes_}
}

function single_local_patch()
{
	downstream_commit=$1

	upstream_commit=$(git show $downstream_commit | grep Mainline: | head -n 1 | awk '{print $2}')
	if [[ x$upstream_commit == x"" ]]; then
		echo "$downstream_commit don't have upstream commit, please re-check." >&2
		return
	fi

	if [[ x$upstream_commit == x"KYLIN-only" ]]; then
		return
	fi

	# verify upstream_commit
	if ! git show "$upstream_commit" >& /dev/null ; then
		echo "$downstream_commit with $upstream_commit is not upstream-commit, please re-check." >&2
		return
	fi

	search_fixes $upstream_commit

	for commit in `cat ${_temp_fixes_}`
	do
		$(dirname $0)/test-commit-in-tree -q $commit
		[ $? == 0 ] && continue

		git --no-pager log -1 --pretty="${downstream_commit:0:12} <- %h %s" $commit >> ${_all_log_fixes}
	done
	rm -rf ${_temp_fixes_}
}

function all_local_patchs()
{
	current_branch=$(git rev-parse --abbrev-ref HEAD)
	[ -z $current_branch ] && echo "I'm not in branch." && exit 1

	commit_start="origin/$current_branch"
	[ ! -z $base_commit ] && commit_start=$base_commit

	commits=$(git log --pretty=oneline HEAD...${commit_start} --reverse | awk '{print $1}')
	[ -z "$commits" ] && echo -e "${RED}You are don't have un-merged commits${RC}" && exit 1

	for commit in $commits
	do
		single_local_patch $commit
	done
}

function all_commits_patchs()
{
	[ ! -f $1 ] && echo "$1 is not found, please check." && exit 1

	for commit in `cat $1`
	do
		single_local_patch $commit
	done
}

function usage()
{
	echo "Usage:"
	echo -e "$0"
	echo -e "\t[-h] [-v <version>]"
	echo -e "\t[-c <commit-id>] [-f <commit-list>]"
	echo -e "\t[-b <start-commit-id>]"
	exit 1
}

function showVersion()
{
	echo "version: $VER"
	exit 1
}

function processing()
{
	while [ 1 ];
	do
		string="\|/-"
		for ((i = 0; i < ${#string}; i++))
		do
			printf "Searching... %-s \r" "${string:$i:1}"
			sleep 0.3
		done
	done
}

function main()
{
	check_git_is_installed
	is_git_repository

	processing &

	if [ ! -z $commit_id ]; then
		single_local_patch $commit_id
	elif [ ! -z $commit_file ]; then
		all_commits_patchs $commit_file
	else
		all_local_patchs
	fi
}

while getopts "hf:d:c:vb:" opt;do
	case "$opt" in
		v) showVersion ;;
		c) commit_id="${OPTARG}" ;;
		f) commit_file="${OPTARG}" ;;
		h) usage ;;
		b) base_commit="${OPTARG}" ;;
		*) usage ;;
	esac
done

main

if [ -f ${_all_log_fixes} ]; then
	if [ `cat ${_all_log_fixes} | wc -l ` -eq 0 ]; then
		printf "                     \r"
		echo -e "${BLUE}Not Found.${RC}"
		ret=1
	else
		cat ${_all_log_fixes}
		ret=0
	fi
	rm -rf ${_all_log_fixes}
	exit $ret
fi
