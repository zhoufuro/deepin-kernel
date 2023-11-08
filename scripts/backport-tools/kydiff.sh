#!/bin/bash

function usage()
{
	echo -e "`basename $0` [commit_id] "
}

if [ -z $1 ];then
	usage;
	exit;
fi

which colordiff
if [ $? -ne 0 ];then
	echo -e "Cann't find colordiff, please install it firstly!"
	exit;
fi

Kpatch=$1;
Upatch=$(git show $1 | grep Mainline: | grep -vi KYLIN-only | awk -F: '{print $2}');

if [ -z $Upatch ];then
	echo -e "$Kpatch is not commit of local repository,or not a patch from upstream!"
	exit;
fi

colordiff -yw -W 200 <(git diff -W ${Kpatch}^-) <(git diff -W ${Upatch}^-) | less -SR
