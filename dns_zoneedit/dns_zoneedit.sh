#!/bin/bash -x

VERB=$1
DOMAIN=$2
RECORD_NAME=$3
RECORD_VALUE=$4
TTL=$5
ZONEEDIT_USER=$6
ZONEEDIT_TOKEN=$7

SCRIPT=$(basename "$0" .sh)

# Simple check to ensure we are running as root - since we setup certs as root and need to secure password in Zoneedit config file
if [ ! -w /etc/passwd ] ; then
	echo "$SCRIPT: Must run as root" >&2
	exit 2
fi

# Create tmp dir if it doesn't exist yet
if [ -z "$TMPDIR" ] ; then
    if [ ! -z "$USERPROFILE" ]; then
        TMPDIR=$USERPROFILE
    else
        TMPDIR=$TMP
    fi
fi
if [ ! -d $TMPDIR ] ; then
	mkdir -p $TMPDIR
fi

COOKIES=$TMPDIR/cookies.txt
DEBUG=0
VERBOSE=0


# Run a curl command
# Usage:
#   CURL url output [data]
# Where:
#      url     is the URL to connect to
#      output  is the prefix of the file to save output to in $TMPDIR
#              this will create 3 files: $output.html - stdout - or html source
#                                        $output.stderr - stderr - or curl status output
#                                        $outut.header - the headers returned from the request

CURL() {
	local URL=$1
	local SESSION=$2
	shift 2
	local DATA=$@
	local CMD="curl -b $COOKIES -c $COOKIES -D $TMPDIR/$SESSION.header $DATA $URL"
	if [ -f $TMPDIR/$SESSION.html ] ; then
		if [ $DEBUG ] ; then
			echo "Found $SESSION.htnl. Not running '$CMD' > $TMPDIR/$SESSION.html 2> $TMPDIR/$SESSION.stderr"
		fi
	else
		if [ $DEBUG ] ; then
			echo "Running '$CMD' > $TMPDIR/$SESSION.html 2> $TMPDIR/$SESSION.stderr"
		elif [ $VERBOSE ] ; then
			echo "$URL"
		fi
		$CMD 2> $TMPDIR/$SESSION.stderr | sed -e "s/>/>\\n/g" > $TMPDIR/$SESSION.html
	fi
}

if [ "$VERB" = "perform" ]]; then
    # Start the process
    # First, we need to access the main login page to initialize cookies and session info
    output "Getting initial login cookies"
    SESSION=01login
    CURL https://cp.zoneedit.com/login.php $SESSION

    # Get the initial token
    token=`grep csrf_token $TMPDIR/$SESSION.html | sed -e "s/.*value=//" | cut -d'"' -f2`
    if [ $DEBUG ] ; then
        echo "csrf_token = '$token'"
    fi

    # Create the required hashes for login
    login_chal=`grep login_chal.*VALUE $TMPDIR/$SESSION.html  | sed -e "s/.*login_chal//" | cut -d'"' -f3`
    if [ $DEBUG ] ; then
        echo "login_chal = '$login_chal'"
    fi
    MD5_pass=`echo "$ZONEEDIT_PASS" | md5sum | cut -d' ' -f1`
    if [ $DEBUG ] ; then
        echo "MD5_pass = '$MD5_pass'"
    fi
    login_hash=`echo "$ZONEEDIT_USER$MD5_pass$login_chal" | md5sum | cut -d' ' -f1`
    if [ $DEBUG ] ; then
        echo "login_hash = '$login_hash'"
    fi

    # Send the login POST request
    output "Logging in"
    SESSION=02home
    CURL https://cp.zoneedit.com/home/ $SESSION -d login_chal=$login_chal -d login_hash=$hash -d login_user=$ZONEEDIT_USER -d login_pass=$ZONEEDIT_PASS -d csrf_token=$token -d login=

    # Check that login was successful
    # when successfull, we get this in the header
    #    Location: https://cp.zoneedit.com/manage/domains/
    # on failure, we get this in the header
    #    Location: https://cp.zoneedit.com/login.php

    LOCATION=`cat $TMPDIR/$SESSION.header | tr '\r' '\n' | grep ^Location: | cut -d' ' -f2`
    if [ $DEBUG ] ; then
        echo "LOCATION = '$LOCATION'"
    fi
    if [ ! "$LOCATION" = "" -a `echo $LOCATION | grep -c manage/domains` -eq 0 ] ; then
        if [ $DEBUG ] ; then
            echo "---------------- headers -----------------"
            cat $TMPDIR/$SESSION.header
            echo "-------------- end headers ---------------"
            echo "--------------- stdout -------------------"
            cat $TMPDIR/$SESSION.html
            echo "------------- end stdout -----------------"
            echo "--------------- stderr -------------------"
            cat $TMPDIR/$SESSION.stderr
            echo "------------- end stderr -----------------"
        fi
        echo "ERROR: Invalid user or password!"
        exit 1
    fi

    # Get our domain list
    output "Validating domain"
    SESSION=03domains
    CURL https://cp.zoneedit.com/manage/domains/ $SESSION

    # Check that the requested domain exists in our domain list
    if [ `grep -c "index.php?LOGIN=$DOMAIN\"" $TMPDIR/$SESSION.html` -eq 0 ] ; then
        echo "ERROR: Invalid domain '$DOMAIN'!"
        exit 1
    fi

    # Access the domain we are wanting to edit
    SESSION=04domain
    CURL https://cp.zoneedit.com/manage/domains/zone/index.php?LOGIN=$DOMAIN $SESSION

    # Check we successfully switched to domain
    if [ `grep -c "^$DOMAIN</" $TMPDIR/$SESSION.html` -eq 0 ] ; then
        echo "ERROR: Unable to access domain '$DOMAIN'!"
        exit 1
    fi

    # Switch to the TXT records edit page
    output "Loading TXT edit page"
    SESSION=05txt
    CURL https://cp.zoneedit.com/manage/domains/txt/ $SESSION

    # Click the edit button
    SESSION=06edit
    CURL https://cp.zoneedit.com/manage/domains/txt/edit.php $SESSION

    # Get the token and other generated values
    FILE=$TMPDIR/$SESSION.html
    token=`grep csrf_token $FILE | sed -e "s/.*value=//" | cut -d'"' -f2`
    if [ $DEBUG ] ; then
        echo "csrf_token = '$token'"
    fi
    multipleTabFix=`grep multipleTabFix $FILE | sed -e "s/.*multipleTabFix//" | cut -d'"' -f3`
    if [ $DEBUG ] ; then
        echo "multipleTabFix = '$multipleTabFix'"
    fi

    # See if this is the second call from certbot
    # the other script always cleans up the folder first, so
    # if this is second call in, then the file will exist
    if [ -f $WORKDIR/txtrecord1 ] ; then
        TXT1=`cat $WORKDIR/txtrecord1`
    else
        # if it's not there, then save our value for the next call
        TXT1=""
        echo "$RECORD_VALUE" >> $WORKDIR/txtrecord1
    fi

    # Figure out which id to use in the TXT records based on our name and id we asked for
    i=0
    found_ids=0
    our_id=-1
    while [ `grep -c TXT::$i::host $FILE` -gt 0 ] ; do
        name=`grep "TXT::$i::host.*value=" $FILE | sed -e "s/.*value=//" | cut -d\" -f2`
        val=`grep "TXT::$i::txt.*value=" $FILE | sed -e "s/.*value=//" | cut -d\" -f2`
        # If the TXT record has no name or the same as ours...
        if [ "$name" = "" -o "$name" = "$RECORD_NAME" ] ; then
            if [ $DEBUG ] ; then
                echo "Checking id $i with name='$name'"
            fi
            # If this isn't the same as previous run (or there no previous run)
            # then use this id for new value
            if [ ! "$val" = "$TXT1" -o "$name" = "" ] ; then
                if [ $VERBOSE ] ; then
                    echo "Using id $i with name='$name'"
                fi
                our_id=$i
                break
            fi
            # If not, just increase found count for next loop
            found_ids=$[$found_ids+1]
        else
            if [ $DEBUG ] ; then
                echo "Skipping id $i with name='$name'"
            fi
        fi
        i=$[$i+1]
    done

    # If we didn't set the id, then we need to abort
    if [ $our_id -eq -1 ] ; then
        echo "ERROR: Failed to find a TXT record to use! Please cleanup some TXT records in ZoneEdit and try again."
        exit 1
    fi

    # If we use file for old data or not (default ="" means no)
    USEFILE_FOR_DATA=""
    # Build the full data set based on what is already configured in the domain
    DATA="-d MODE=edit -d csrf_token=$token -d multipleTabFix=$multipleTabFix"
    i=0
    while [ `grep -c TXT::$i::host $FILE` -gt 0 ] ; do
        name=`grep "TXT::$i::host.*value=" $FILE | sed -e "s/.*value=//" | cut -d\" -f2`
        if [ $DEBUG ] ; then
            echo "TXT::$i::host = '$name'"
        fi
        val=`grep "TXT::$i::txt.*value=" $FILE | sed -e "s/.*value=//" | cut -d\" -f2 | tr ' ' +`
        if [ $DEBUG ] ; then
            echo "TXT::$i::txt = '$val'"
        fi
        ttl=`grep "TXT::$i::ttl.*value=" $FILE | sed -e "s/.*value=//" | cut -d\" -f2`
        if [ $DEBUG ] ; then
            echo "TXT::$i::ttl = '$ttl'"
        fi
        if [ $i -eq $our_id ] ; then
            # If it's the record we are asking to edit, the set values based on what we passed in
            if [ $DEBUG ] ; then
                echo "Using our values for TXT::$i::...."
            fi
            DATA="$DATA -d TXT::$i::host=$RECORD_NAME"
            DATA="$DATA -d TXT::$i::txt=$RECORD_VALUE"
            DATA="$DATA -d TXT::$i::ttl=$txt_ttl"
        elif [ ! "$name" = "" ] ; then
            # Otherwise, get existing data to pass back in
            if [ $DEBUG ] ; then
                echo "Using values already set for TXT::$i::...."
            fi
            if [ $USEFILE_FOR_DATA ] ; then
                echo "TXT::$i::host=$name" > $TMPDIR/data-name-$i
                echo "TXT::$i::txt=$val" > $TMPDIR/data-txt-$i
                DATA="$DATA --data-urlencode @$TMPDIR/data-name-$i"
                DATA="$DATA --data-urlencode @$TMPDIR/data-txt-$i"
            else
                DATA="$DATA -d TXT::$i::host=$name"
                DATA="$DATA -d TXT::$i::txt=$val"
            fi
            DATA="$DATA -d TXT::$i::ttl=$ttl"
        fi
        i=$[$i+1]
    done

	# Send the new values (click on the save button)
	output "Sending new TXT record values"
	SESSION=07save
	CURL https://cp.zoneedit.com/manage/domains/txt/edit.php $SESSION $DATA

	# Get token and other values
	FILE=$TMPDIR/$SESSION.html
	CSRF_TOKEN=`grep csrf_token $FILE | sed -e "s/.*value=//" | cut -d'"' -f2`
	if [ $DEBUG ] ; then
		echo "csrf_token = '$CSRF_TOKEN'"
	fi
	multipleTabFix=`grep multipleTabFix $FILE | sed -e "s/.*multipleTabFix//" | cut -d'"' -f3`
	if [ $DEBUG ] ; then
		echo "multipleTabFix = '$multipleTabFix'"
	fi
	NEW_TXT=`grep hidden.*NEW_TXT $FILE  | sed -e "s/.*NEW_TXT//" | cut -d'"' -f3`
	if [ $DEBUG ] ; then
		echo "NEW_TXT = '$NEW_TXT'"
	fi
#<img src="https://cp.zoneedit.com/images/common/error_arrow.gif" border="0" width="11" height="10" alt="error" title="error" />
# <font class="error">
#No IPs detected in SPF</font>
#<br />
	ERROR_MESSAGE=`grep -A1 'font class="error"' $FILE | tail -1 | cut -d'<' -f1`
	if [ ! "$ERROR_MESSAGE" = "" ] ; then
		cat $FILE
		ERROR_BLOCK=`cat $FILE | sed -n '/.*td class="errorBlock.*/,/.*<\/td>.*/p' | egrep -v '^$|<td|td>'`
		echo "$ERROR_BLOCK"
		echo "ERROR: $ERROR_MESSAGE!"
		exit 1
	elif [ "$NEW_TXT" = "" -o "$CSRF_TOKEN" = "" -o "$multipleTabFix" = "" ] ; then
		cat $FILE
		echo "ERROR: Failed to find NEW_TXT, csrf_token or multipleTabFix in $FILE!" >&2
		exit 1
	fi

	# Save the new values (click the confirm button)
	SESSION=08confirm
	CURL https://cp.zoneedit.com/manage/domains/txt/confirm.php $SESSION -d csrf_token=$CSRF_TOKEN -d confirm= -d multipleTabFix=$multipleTabFix -d NEW_TXT=$NEW_TXT
	# Expect to see:
#Thank You. Your new DNS information for <b>
#jeansergegagnon.com</b>
# is now in place.
#</p>
	# Finally, get the table back to confirm settings saves properly
	output "Confirming change succeeded"
	SESSION=09edit
	CURL https://cp.zoneedit.com/manage/domains/txt/edit.php $SESSION

	# Check that new values are what we expect
	FILE=$TMPDIR/$SESSION.html
	FOUNDIT=""
	i=0
	while [ `grep -c TXT::$i::host $FILE` -gt 0 ] ; do
		name=`grep "TXT::$i::host.*value=" $FILE | sed -e "s/.*value=//" | cut -d\" -f2`
		if [ $DEBUG ] ; then
			echo "TXT::$i::host = '$name'"
		fi
		val=`grep "TXT::$i::txt.*value=" $FILE | sed -e "s/.*value=//" | cut -d\" -f2`
		if [ $DEBUG ] ; then
			echo "TXT::$i::txt = '$val'"
		fi
		if [ "$name" = "$RECORD_NAME" -a "$val" = "$RECORD_VALUE" ] ; then
			FOUNDIT=1
			break
		fi
		i=$[$i+1]
	done
	if [ $FOUNDIT ] ; then
		echo "OK: Successfully set TXT record $RECORD_NAME.$DOMAIN=$RECORD_VALUE" >&2
	else
		echo "ERROR: Did not find $RECORD_NAME.$DOMAIN=$RECORD_VALUE in new records!" >&2
		exit 1
	fi
    exit 0
fi

if [ "$VERB" = "cleanup" ]]; then
    # We don't need to delete anything, strictly speaking
    exit 0
fi

echo "$SCRIPT: Invalid verb: $VERB" >&2
exit 1

