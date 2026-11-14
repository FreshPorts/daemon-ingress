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
	cd ${SCRIPTDIR}

	if [ -e 'OFFLINE' ]
	then
		echo "system is OFFLINE: ${SCRIPTDIR}/OFFLINE exists"
		break
	else
		check_for_jobs
	fi
	sleep 3
done
