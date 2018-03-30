#!/bin/bash
#
# AUTHOR: raju.guggilla
#
# REQUIREMENTS:: 'jq' tool is to be installed on the system
#		 'nc' utility is to be installed on the system

JQ=/usr/bin/jq

#nc from the netcat-openbsd package. An alternative nc is available
NC=/bin/nc

# Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

# specify the limit for the running jobs
JOBS_RUNNING=${JOBS_RUNNING:=17}

# flink data dir to hold the json files
FLINK_DATA_DIR=/tmp/flink-data
if ! [ -d $FLINK_DATA_DIR ]; then
   mkdir $FLINK_DATA_DIR
fi

# Checking 'jq' package exists on the system 
#
if [ ! -x $JQ ]; then
        echo "UNKNOWN -  jq not found or is not executable by the nagios user."
        exit $STATE_UNKNOWN
fi

# Checking 'nc' package exists on the system
#
if [ ! -x $NC ]; then
        echo "UNKNOWN - nc not found or is not executable by the nagios user."
        exit $STATE_UNKNOWN
fi

# Usage of this script 
#
usage()
{
cat <<EOF
  check the flink jobs with its state.
 
  Arguments: 
  -H <hostname/ip-address>  specify the ip-address of the flink
  -p <port>		    specify the port, on which its listening on
  -s <state>		    specify the state, such as running or completed.
  -h 	 		    show this page

  Usage: 
   $0 -H <ip-address> -p <port> -s <state> 
EOF
}

# Checking for the arguments
#
argcheck()
{
   if [ $ARGC -lt $1 ]; then
         echo "Missing arguments..! Use \`\`-h'' for help."
         exit 1
   fi
}

# This function get the data from flink api 
# and parse the json data
#
flink_get_data()
{
   #echo "Getting data from flink..."
   #echo ".........................................."
   #sleep 1
   get_data=`curl -s $flink_url/joboverview/$STATE -w json -o $data_json`

   jobs=`cat $data_json | jq '.jobs[].name' | sed -e 's/\"//g'`
   jobs_count=`cat $data_json | jq '.jobs[].name' | wc -l`

   #echo -e "==================== $STATE jobs  ===============================================\n"
   #echo -e "$jobs\n"
   #echo "==================== END  ==============================================="

   if [ $STATE == "running" ];then
      if [ $JOBS_RUNNING -le $jobs_count ]; then
          echo "JOBS OK - $jobs_count jobs are $STATE  "
          exit $OK
      elif [ $JOBS_RUNNING -gt $jobs_count ]; then
          echo "CRITICAL - $jobs_count jobs are $STATE  "
          exit $CRITICAL
      fi
   elif [ $STATE == "completed" ];then
          echo "JOBS OK - $jobs_count jobs are $STATE "
          exit $OK
   else
           exit $UNKNOWN
   fi
}

# This function test the connection established
#
flink_job()
{
   flink_url="http://$HOSTNAME:$PORT"
   data_json="$FLINK_DATA_DIR/$STATE-jobs.json"

   nc -z $HOSTNAME $PORT
   if [ $? -eq 0 ]; then 
      case $STATE in 
           "running")
	       flink_get_data
	       ;;
           "completed")
	       flink_get_data
	       ;;
           *)
               echo "UNKNOWN - Please give state value for -s either running or completed."
	       exit $UNKNOWN
               ;; 
      esac
   else
      echo "UNKNOWN - Connection not established. Please check the ip-address and port values"
      exit $UNKNOWN
   fi
}

ARGC=$#
HOSTNAME=".*"
PORT=".*"
STATE=".*"

flag1=0
flag2=0
flag3=0

argcheck 1

while getopts "hH:p:s:" OPTION 
do
    case $OPTION in 
	h)
	    usage
	    exit 0
	    ;;
    	H)
	    HOSTNAME="$OPTARG"
	    flag1=1
	    ;;
	p)
	    PORT="$OPTARG"
	    flag2=1
	    ;;
        s)
	    STATE="$OPTARG"
	    flag3=1
	    ;;
	\?)
	    echo -e "use -h for help"
            exit 1
            ;;
    esac
done

if [ $flag1 -eq 0 ] || [ $flag2 -eq 0 ] || [ $flag3 -eq 0 ]; then 
     echo "All arguments are mandatory..!"
     echo "Use -h for the usage of script."
     exit 1
else
     flink_job
fi


