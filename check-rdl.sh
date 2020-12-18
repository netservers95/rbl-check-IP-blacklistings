#!/bin/bash
#set -x;	# Enable Debug Mode

result_path=$(dirname "${BASH_SOURCE[0]}";);
#echo ${result_path};
[ -f "${result_path}/results" ] && rm -f ${result_path}/results;

# RBL list from http://www.anti-abuse.org/multi-rbl-check/
rbl_servers=$(sqlite3 ${result_path}/lists.db "select server_address from rbl_servers where use IS NULL";);
if [ -n "$1" ]; then
	ip="$1";
	echo "Checking $server ($ip) against RBL's";
	reverse_ip=$(echo $ip | perl -pe 's/(\d+)\.(\d+)\.(\d+)\.(\d+)/$4.$3.$2.$1/g';);
	for rbl in $rbl_servers; do
		{
			result=$(dig +short $reverse_ip.$rbl | head -n +1;);
			if [ -n "$result" ]; then
				if [ `echo "$result" | grep -ic ';;.*'` -eq "0" ]; then
					ptr=$(dig +short +tcp -x $ip | perl -pe 's/(.*)\.$/$1/g');
					[ `echo "$ptr" | grep -ic ';;.*'` -eq "0" ] && echo "$prt ($ip) is in $rbl with code $result" >> "${result_path}/results" || echo "($ip) is in $rbl with code $result" >> "${result_path}/results";
				else
					ptr=$(dig +short +tcp -x $ip | perl -pe 's/(.*)\.$/$1/g');
					[ `echo "$ptr" | grep -ic ';;.*'` -eq "0" ] && echo "$ptr ($ip) timed out against $rbl" >> "${result_path}/results" || echo "($ip) timed out against $rbl" >> "${result_path}/results";
				fi;
			fi;
		} &
	done;
	wait;
	cat "${result_path}/results" | sort -n;
	exit;
fi;

check_ips=$(sqlite3 ${result_path}/lists.db "select ip from check_servers";);
for server in $check_ips; do
	reverse_ip=$(echo $server | perl -pe 's/(\d+)\.(\d+)\.(\d+)\.(\d+)/$4.$3.$2.$1/g';);
	{
		for rbl in $rbl_servers; do
			result=$(dig +short $reverse_ip.$rbl | head -n +1;);
			if [ -n "$result" ]; then
				if [ `echo "$result" | grep -ic ';;.*'` -eq "0" ]; then
					ptr=$(dig +short +tcp -x $server | perl -pe 's/(.*)\.$/$1/g');
					[ `echo "$ptr" | grep -ic ';;.*'` -eq "0" ] && echo "$ptr ($server) is in $rbl with code $result" >> "${result_path}/results" || echo "($server) is in $rbl with code $result" >> "${result_path}/results";
				else
					ptr=$(dig +short +tcp -x $server | perl -pe 's/(.*)\.$/$1/g');
					[ `echo "$ptr" | grep -ic ';;.*'` -eq "0" ] && echo "$ptr ($server) timed out against $rbl" >> "${result_path}/results" || echo "($server) timed out against $rbl" >> "${result_path}/results";
				fi;
			fi;
		done;
	} &
done;

# Generate Email Report
status () {
	[ $1 == "0" ] && status="- No blacklists active on any IP's\n\n";
	[ $1 == "1" ] && status="- Blacklist's on the following IP's.\n\n";
	SUBJECT="Blacklist Report";
	FROM="blackliste@local";
	TO="youremail@local";

/usr/bin/mail -s "$SUBJECT" -r "$FROM" "$TO" <<-EOF
	`/bin/date '+Date: %d %b %Y%nTime: %H:%M';`
		`echo -e "$status";`

		`[ $1 == "1" ] && cat "${result_path}/results" | sort -n;`
	EOF
};

wait;
[ ! -f "${result_path}/results" ] && status 0 || status 1;

