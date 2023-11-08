#!/bin/bash

###################### MERGE SOURCE TREE  ##########################

if [ $# -lt 1 ]; then
	echo "请输入源分支"
	exit
fi

function generate_changelog()
{
	IDS=`git log $1...$2 --pretty="format: %H %s " | grep -v "Merge branch" | grep -v "KYLIN: changelog" | awk -F' ' '{print $1}'`

	for id in $IDS
	do
		task_id=`git show --no-patch $id | grep "[Tt]ask: \?\#\?[0-9]\{4,\}\|[Bb]ug: \?\#\?[0-9]\{4,\}" | sed -e 's/ //g' | sed -e 's/#//g'`;
		if [ x"$task_id" != x"" ]; then
			task_id=" [`echo $task_id | sed 's/ /, /g'`]"
		fi

		cve_id=`git show --no-patch $id | grep "CVE: \?CVE-[0-9]\{4,\}-[0-9]\{1,\}" | sed -e 's/CVE://g'`
		if [ x"${cve_id}" != x"" ]; then
			cve_id=" {`echo ${cve_id} | sed 's/ /, /g'`}"
		fi

		git show --no-patch --pretty="$3${task_id,,}${cve_id^^}" $id >> $4
		echo "" >> $4
	done
}

git reset --hard
THIS_BRANCH=`git branch | grep "*"  | awk -F' ' '{print $2}'`

git checkout -b my_test --force

LAST_VERSION=`git log  -n 1  --pretty="%H" Makefile`
SRC_BRANCH=$1

# 展开合并
git merge $SRC_BRANCH

# 提交合并
COMMIT_MSG=`git shortlog HEAD...${LAST_VERSION} | head -n 100`

git checkout $THIS_BRANCH --force

git merge --no-commit --no-ff $SRC_BRANCH
git commit -s -m "Merge branch $SRC_BRANCH into $THIS_BRANCH

$COMMIT_MSG
"
git branch -D my_test

###################### UPDATE KERNEL VERSION ##########################

# 更新 Makefile 的版本信息
V=`sed -n 's/^EXTRAVERSION = -//p' Makefile`
RC=`sed -n 's/^KYLIN_RC_VERSION = //p' Makefile`

if [ $((RC)) == 0 ]; then
	let NOW=$((V))+1
else
	let NOW=$((V))
fi

# keep them zero
RC_NOW="0"
RC_STRING="0"

sed -i "/EXTRAVERSION =/d" Makefile
sed -i "/SUBLEVEL =/aEXTRAVERSION = -${NOW}" Makefile
sed -i "/KYLIN_RC_VERSION =/d" Makefile
sed -i "/EXTRAVERSION =/aKYLIN_RC_VERSION = ${RC_NOW}" Makefile

VERSION=`sed -n 's/^VERSION = //p' Makefile`
PATCHLEVEL=`sed -n 's/^PATCHLEVEL = //p' Makefile`
SUBLEVEL=`sed -n 's/^SUBLEVEL = //p' Makefile`

branch_name=v2307
# 更新 Spec 文件 Version 信息
sed -i "s/\%define midv.*/\%define midv $NOW/" rpmbuild/SPECS/kernel.spec
sed -i "s/\%define subv.*/\%define subv $RC_STRING/" rpmbuild/SPECS/kernel.spec

# 新增 RPM changelog 信息
TEMPFILE="/tmp/.changelog"
DATE_=`LC_ALL=en_US.UTF-8 date +'%a %b %d %Y'`
echo "* $DATE_ Jackie Liu <liuyun01@kylinos.cn> - ${VERSION}.${PATCHLEVEL}.${SUBLEVEL}-${NOW}.${RC_STRING}.${branch_name}" > $TEMPFILE
generate_changelog HEAD ${LAST_VERSION} "format:- %s (%aN)" $TEMPFILE
echo "" >> $TEMPFILE

sed -i "/%changelog/r $TEMPFILE" rpmbuild/SPECS/kernel.spec

# 新增 Deb changelog 信息
echo "linux (4.19.90-${NOW}.${RC_STRING}.${branch_name}) stable; urgency=low" > $TEMPFILE
echo "" >> $TEMPFILE
generate_changelog HEAD ${LAST_VERSION} "format:  * %s (%aN)" $TEMPFILE
echo "" >> $TEMPFILE
echo " -- JackieLiu <liuyun01@kylinos.cn>  `date -R`" >> $TEMPFILE
echo "" >> $TEMPFILE
cat debian.master/changelog >> $TEMPFILE
\mv $TEMPFILE debian.master/changelog

git commit -s -am  "Update kernel version to ${VERSION}.${PATCHLEVEL}.${SUBLEVEL}-${NOW}.${RC_STRING}.${branch_name}
"
