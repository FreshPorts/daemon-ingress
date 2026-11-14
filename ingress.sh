#!/bin/sh
#
# $Id: fp-daemon.sh,v 1.17 2006-11-10 14:08:26 dan Exp $
#
# Copyright (c) 2001-2003 DVL Software
#
#
# include our local parameters

. /usr/local/etc/freshports/ingress.sh

#
# The flag directory.  ingress.sh has read INGRESS_FLAGDIR since 1609260
# (2020-07-18), but this repo's config sample went on setting FLAGDIR, the
# name from 2015.  With only FLAGDIR set, FLAG below was "/job_waiting",
# which never exists: job-waiting.pl never ran, so neither did check_git.sh,
# and no new commits were fetched, with nothing logged.  Accept the old
# name, and refuse to start without either.
#
INGRESS_FLAGDIR=${INGRESS_FLAGDIR:-${FLAGDIR}}
if [ -z "${INGRESS_FLAGDIR}" ]
then
	echo "FATAL: neither INGRESS_FLAGDIR nor FLAGDIR is set in /usr/local/etc/freshports/ingress.sh"
	exit 1
fi

CP='/bin/cp'

# we do not use -i because that would fail when re re-run a commit
MV='/bin/mv'

RM='/bin/rm'

PERL='/usr/local/bin/perl'

#
# sanity checking upon startup
#

check_for_jobs() {
	#
	# job_waiting only wakes job-waiting.pl, which then runs a job for each
	# of the other flags it finds, until none is left.  Remove it before
	# running job-waiting.pl, not after.
	#
	# This is the ingress user's job_waiting, in INGRESS_FLAGDIR; the
	# freshports user has its own.  It is not set by jobs this script runs,
	# as this comment used to say, but by check_for_git_commits.sh from
	# cron, along with check_git, the ingress user's only job.
	# Removed afterwards, a flag set while job-waiting.pl was finishing was
	# deleted unread, and that job waited for the next wake-up.
	# Removed first, it survives, and the next pass of the loop runs
	# job-waiting.pl again.
	#
	# asked to stop: start no new job
	[ ${STOP_REQUESTED} = 1 ] && return

	FLAG="${INGRESS_FLAGDIR}/job_waiting"
	if [ -f ${FLAG} ]
	then
		rm -f ${FLAG}
		cd ${SCRIPTDIR}
		echo "yes, there is a job waiting"
		echo "running ${PERL} ./job-waiting.pl"
		echo "from directory  ${SCRIPTDIR}"
		ls -l ./job-waiting.pl
		${PERL} ./job-waiting.pl
		# saved at once: by the echo below, $? was the [ test's (always 1)
		status=$?
		if [ $status -eq 0 ]
		then
			echo "job-waiting.pl finishes normally"
		else
			echo "FATAL job-waiting.pl finished with an error: $status"
		fi
	fi
}

echo "starting up!"

#
# Stopping: finish the job in hand, start nothing new, then exit.
#
# "service ingress stop" sends SIGTERM to daemon(8), which passes it to this
# shell only, not to the job it is running.  With no trap the shell died at
# once and that job -- job-waiting.pl and whatever it was running, such as
# check_git.sh -- carried on with no parent; a restart then started a
# second loop beside it.
#
# sh runs a trap only once the command in the foreground has returned, so
# the job is never cut off: the trap just notes the request, and the loop
# checks it before starting anything else.
#
STOP_REQUESTED=0
trap 'STOP_REQUESTED=1; echo "stop requested: finishing the current job first"' TERM INT

if [ ! -d ${SCRIPTDIR} ]
then
	echo "Required directory does not exist: ${SCRIPTDIR}"
	exit
fi

if [ ! -d ${INGRESS_MSGDIR}/incoming ]
then
	echo "Required directory does not exist: ${INGRESS_MSGDIR}/incoming"
	exit
fi

echo incoming: ${INGRESS_MSGDIR}/incoming
echo ready

while :
	do
	if [ ${STOP_REQUESTED} = 1 ]
	then
		echo "stopping, as requested"
		exit 0
	fi

	cd ${SCRIPTDIR}

	if [ -e 'OFFLINE' ]
	then
		echo "system is OFFLINE: ${SCRIPTDIR}/OFFLINE exists"
		break
	else
		check_for_jobs
	fi
	# no pause once asked to stop: the check at the top exits
	[ ${STOP_REQUESTED} = 1 ] || sleep 3
done
