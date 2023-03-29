#!/usr/local/bin/bash
usage() {
echo -n -e "\nUsage: sahw2.sh {--sha256 hashes ... | --md5 hashes ...} -i files ...\n\n--sha256: SHA256 hashes to validate input files.\n--md5: MD5 hashes to validate input files.\n-i: Input files.\n"
}
if [ $# = 1 ]; then
	if [ $1 = "-h" ]; then
		usage
		exit 0
	else
		echo "Error: Invalid arguments." >&2
		usage
		exit 1
	fi
fi
if [ $1 != "-i" -a $1 != "--md5" -a $1 != "--sha256" ]; then
	echo "Error: Invalid arguments." >&2
	usage
	exit 1
fi
argc=$#
argc=$(( $argc % 2 ))
temp=0
count=0
checksum=0
file=0
hash=""
for i in $*; do
	count=$(( $count + 1 ))
	if [ $i = "--md5" ]; then
		temp=$(( $temp + 1 ))
		if [ $temp == 2 ]; then
		       echo "Error: Only one type of hash function is allowed." >&2
		       exit 1
		fi
		hash="md5"
		checksum=$count
	elif [ $i = "--sha256" ]; then
		temp=$(( $temp + 1 ))
		if [ $temp == 2 ]; then
			echo "Error: Only one type of hash function is allowed." >&2
			exit 1
		fi
		hash="sha256"
		checksum=$count
	elif [ $i = "-i" ]; then
		file=$count
	fi
done
whilecount=0
if [ $file -gt $checksum ]; then
	whilecount=$file
	if [ $(( $# - $file )) != $(( $file - 2 )) ];then
      		echo "Error: Invalid values." >&2
		exit 1
	fi
else
	whilecount=$checksum
	if [ $(( $# - $checksum )) != $(( $checksum - 2 )) ]; then
		echo "Error: Invalid values." >&2
		exit 1
	fi
fi
tempfile=$file
tempchecksum=$checksum
tempchecksum=$(( $tempchecksum + 1 ))
tempfile=$(( $tempfile + 1 ))
count=0
while [ $count != $(( $whilecount - 2 )) ]; do
	count=$(( $count + 1 ))
	realmd5checksum=$(md5 ${!tempfile} | cut -d ' ' -f 4)
        realshachecksum=$(sha256 ${!tempfile} | cut -d ' ' -f 4)
	fileformat=$(file ${!tempfile} | cut -d ' ' -f 2)	
	if [ $hash = "md5" ]; then
		if [ ${!tempchecksum} != $realmd5checksum ]; then
			echo "Error: Invalid checksum." >&2
			exit 1
		elif [ $fileformat != "JSON" -a $fileformat != "CSV" ]; then
			echo "Error: Invalid file format." >&2
			exit 1
		fi
	elif [ $hash = "sha256" ]; then
		if [ ${!tempchecksum} != $realshachecksum ]; then
			echo "Error: Invalid checksum." >&2
			exit 1
		elif [ $fileformat != "JSON" -a $fileformat != "CSV" ]; then
			echo "Error: Invalid file format." >&2
			exit 1
		fi
	fi
	tempchecksum=$(( $tempchecksum + 1 ))
	tempfile=$(( $tempfile + 1 ))
done
tempfile=$file
tempfile=$(( $tempfile + 1 ))
username=()
password=()
groups=()
shell=()
count=0
while [ $count != $(( $whilecount - 2 )) ]; do
	count=$(( $count + 1 ))
	fileformat=$(file ${!tempfile} | cut -d ' ' -f 2)
	if [ $fileformat = "JSON" ]; then
		usernumber=`cat ${!tempfile} | jq -r ".[] | .username" | cat -n | awk '{ print $1 }' | tail -1`
		tempnum=1
		while [ $tempnum != $(( $usernumber + 1 )) ];do
			username[$(( ${#username[@]} + 1 ))]=`cat ${!tempfile} | jq -r ".[] | .username" | sed -n "${tempnum}p"`	
			password[$(( ${#password[@]} + 1 ))]=`cat ${!tempfile} | jq -r ".[] | .password" | sed -n "${tempnum}p"`
			
			shell[$(( ${#shell[@]} + 1 ))]=`cat ${!tempfile} | jq -r ".[] | .shell" | sed -n "${tempnum}p"`
			
			groups[$(( ${#groups[@]} + 1 ))]=`cat ${!tempfile} | jq ".[] | .groups" | tr -d '\"\n' | sed 's/ //g' | grep -o "\[[^]]*]" | sed 's/\[//;s/\]//' | sed -n "${tempnum}p"`
			tempnum=$(( $tempnum + 1 ))
		done

	elif [ $fileformat = "CSV" ]; then
		usernumber=`cat ${!tempfile} | tail -n+2 | cat -n | awk '{ print $1 }' | tail -1`
		tempnum=1
		while [ $tempnum != $(( $usernumber + 1 )) ]; do
			username[$(( ${#username[@]} + 1 ))]=`awk '{ print $1 }' ${!tempfile} | sed -e 's/,/ /g' | tail -n+2 | awk '{ print $1 }' | sed -n "${tempnum}p"`
		
			password[$(( ${#password[@]} + 1 ))]=`awk '{ print $1 }' ${!tempfile} | sed -e 's/,/ /g' | tail -n+2 | awk '{ print $2 }' | sed -n "${tempnum}p"`
			shell[$(( ${#shell[@]} + 1 ))]=`awk '{ print $1 }' ${!tempfile} | sed -e 's/,/ /g' | tail -n+2 | awk '{ print $3 }' | sed -n "${tempnum}p"`
			groups[$(( ${#groups[@]} + 1 ))]=`cat ${!tempfile} | tail -n+2 | cut -d ',' -f 4 | sed -e 's/ /,/g' | sed 's/,//' | sed -n "${tempnum}p"`
			tempnum=$(( $tempnum + 1 ))
		done
	fi
	tempfile=$(( $tempfile + 1 )) 
done
echo -n "This script will create the following user(s): "
for element in ${username[@]}; do
	echo -n "$element "
done
echo -n "Do you want to continue? [y/n]:"
read -n 1 choice
if [[ $choice == "n" ]]; then
	exit 0
elif [[ $choice == "y" ]]; then
	echo ""
	count=0
	while [ $count != ${#username[@]} ]; do
		count=$(( $count + 1 ))
		error=$(pw usershow ${username[$count]} 2>&1 >/dev/null)
		if [[ $? -eq 0 ]]; then
			echo "Warning: user ${username[$count]} already exists."
			continue
		fi
		g=`echo ${groups[$count]} | sed -e 's/,//g' | sed 's/\(.\{9\}\)/\1,/g; s/,$//'`
		groups[$count]=$g
		gg=`echo $g | sed -e 's/,/ /g'`
		for i in $gg; do

			if ! pw groupshow $i >/dev/null 2>&1; then
				pw groupadd $i >/dev/null
			fi
		done
		if [ "${groups[$count]}" == "" ]; then
			pw useradd -n "${username[$count]}" -s "${shell[$count]}"
		else
			pw useradd -n "${username[$count]}" -s "${shell[$count]}" -G "${groups[$count]}"
		fi
		echo "${password[$count]}" | pw usermod "${username[$count]}" -h 0
	done	
else
	exit 0
fi
