#!/bin/bash

SEVERITY_LEVEL="Low"
K2CI_ARCH="K2CI-Arch: All"
PREFIX=""

function usage()
{
	echo -e "`basename $0` [OPTION]... "
	echo ""
	echo -e "  -h, --help\t\t\tshow this help info"
	echo -e "  -b, --bug\t\t\trequire bug id, insert to commit body"
	echo -e "  -t, --task\t\t\trequire task id, insert to commit body"
	echo -e "  -a, --k2ci-arch\t\tuse for K2CI-Arch, None/Amd64/Arm64/Loongarch..."
	echo -e "             \t\t\t[default = All]"
	echo -e "  -l, --level\t\t\tseverity level from [0-3], mean Low/Moderate/Important/Critical"
	echo -e "             \t\t\t[default = 0]"
	echo -e "  -p, --prefix\t\t\tuse this prefix to title."
	echo ""
	echo "Examples:"
	echo "  sync-third -p EULER -b 10243 -t 6009 -a \"Arm64|Amd64\" "
}

ARGS=`getopt -o hb:t:a:l:p: -a --long help,bug:,task:,k2ci-arch:,level:,prefix: -- "$@"`
[ $? != 0 ] && echo "Terminating..." && usage && exit -1

eval set -- "${ARGS}"

while true
do
	case $1 in
		-h|--help)
			usage
			exit 0;;
		-b|--bug)
			TASK_AND_BUG_ID_LIST="${TASK_AND_BUG_ID_LIST}bug: $2%n"
			SEVERITY_LEVEL="Moderate"
			shift 2;;
		-t|--task)
			TASK_AND_BUG_ID_LIST="${TASK_AND_BUG_ID_LIST}task: $2%n"
			SEVERITY_LEVEL="Moderate"
			shift 2;;
		-a|--k2ci-arch)
			K2CI_ARCH="K2CI-Arch: $2"
			shift 2;;
		-l|--level)
			(( $2 == 0 )) && SEVERITY_LEVEL_FORCE="Low"
			(( $2 == 1 )) && SEVERITY_LEVEL_FORCE="Moderate"
			(( $2 == 2 )) && SEVERITY_LEVEL_FORCE="Important"
			(( $2 >= 3 )) && SEVERITY_LEVEL_FORCE="Critical"
			shift 2;;
		-p|--prefix)
			PREFIX=$2
			shift 2;;
		--)
			shift
			break;;
	esac
done


# check args
[ $# -gt 1 ] && usage && exit -1
[ -z "$TASK_AND_BUG_ID_LIST" ] && usage && exit -2

if test -z "$PREFIX";then
	msg=$(git log -1 --format="%s%n\
	%nMainline: KYLIN-only\
	%nSeverity: ${SEVERITY_LEVEL}%n\
	%n${TASK_AND_BUG_ID_LIST}%n\
	%n%b\
	%n${K2CI_ARCH}")
else
	msg=$(git log -1 --format="${PREFIX}: %s%n\
	%nMainline: KYLIN-only\
	%nSeverity: ${SEVERITY_LEVEL}%n\
	%n${TASK_AND_BUG_ID_LIST}%n\
	%n%b\
	%n${K2CI_ARCH}")
fi

git commit -s --amend -m "$msg"
