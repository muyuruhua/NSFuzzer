#!/bin/bash

export NUM_CONTAINERS="${NUM_CONTAINERS:-4}"
# export TIMEOUT="${TIMEOUT:-120}"
export TIMEOUT=$4
export SKIPCOUNT="${SKIPCOUNT:-1}"

export TARGET_LIST=$1
export FUZZER_LIST=$2

BASE_DIR=`dirname $0`
PFBENCH=`realpath ${BASE_DIR}`
OUTDIR=$3


if [[ "x$TARGET_LIST" == "x" ]] || [[ "x$FUZZER_LIST" == "x" ]]
then
    echo "Usage: $0 TARGET FUZZER"
    exit 1
fi

echo
echo "# NUM_CONTAINERS: ${NUM_CONTAINERS}"
echo "# TIMEOUT: ${TIMEOUT}"
echo "# SKIPCOUNT: ${SKIPCOUNT}"
echo "# TARGET LIST: ${TARGET_LIST}"
echo "# FUZZER LIST: ${FUZZER_LIST}"
echo "# OUTDIR: ${OUTDIR}"
echo

for FUZZER in $(echo $FUZZER_LIST | sed "s/,/ /g")
do

    for TARGET in $(echo $TARGET_LIST | sed "s/,/ /g")
    do

        echo
        echo "***** RUNNING $FUZZER ON $TARGET *****"
        echo

##### FTP #####

        if [[ $TARGET == "lightftp" ]] || [[ $TARGET == "all" ]]
        then

            cd $PFBENCH
            mkdir -p $OUTDIR

            if [[ $FUZZER == "aflnet" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh lightftp $NUM_CONTAINERS $OUTDIR aflnet out-lightftp-aflnet "-P FTP -D 10000 -q 3 -s 3 -E -K -R -m none" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "stateafl" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh lightftp-stateafl $NUM_CONTAINERS $OUTDIR stateafl out-lightftp-stateafl "-P FTP -D 10000 -q 3 -s 3 -E -K -R -m none -t 2000" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "nsfuzz" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh lightftp-nsfuzz $NUM_CONTAINERS $OUTDIR nsfuzz out-lightftp-nsfuzz "-P FTP -D 10000 -q 3 -s 3 -E -K -R" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "nsfuzz-v" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh lightftp-nsfuzz-v $NUM_CONTAINERS $OUTDIR nsfuzz-v out-lightftp-nsfuzz-v "-P FTP -D 10000 -q 3 -s 3 -E -K -R -m none" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "aflnwe" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh lightftp $NUM_CONTAINERS $OUTDIR aflnwe out-lightftp-aflnwe "-D 10000 -K" $TIMEOUT $SKIPCOUNT &
            fi

        fi


        if [[ $TARGET == "bftpd" ]] || [[ $TARGET == "all" ]]
        then

            cd $PFBENCH
            mkdir -p $OUTDIR

            if [[ $FUZZER == "aflnet" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh bftpd $NUM_CONTAINERS $OUTDIR aflnet out-bftpd-aflnet "-t 1000+ -m none -P FTP -D 10000 -q 3 -s 3 -E -K -R" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "stateafl" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh bftpd-stateafl $NUM_CONTAINERS $OUTDIR stateafl out-bftpd-stateafl "-t 2000 -m none -P FTP -D 10000 -q 3 -s 3 -E -K" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "nsfuzz" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh bftpd-nsfuzz:v5.7-backup $NUM_CONTAINERS $OUTDIR nsfuzz out-bftpd-nsfuzz "-t 1000+ -m none -P FTP -D 10000 -w 1000 -q 3 -s 3 -E -K -R" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "nsfuzz-v" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh bftpd-nsfuzz:v5.7-backup $NUM_CONTAINERS $OUTDIR nsfuzz-v out-bftpd-nsfuzz-v "-t 1000+ -m none -P FTP -D 10000 -q 3 -s 3 -E -K -R" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "aflnwe" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh bftpd $NUM_CONTAINERS $OUTDIR aflnwe out-bftpd-aflnwe "-t 1000+ -m none -D 10000 -K" $TIMEOUT $SKIPCOUNT &
            fi

        fi


        if [[ $TARGET == "proftpd" ]] || [[ $TARGET == "all" ]]
        then

            cd $PFBENCH
            mkdir -p $OUTDIR

            if [[ $FUZZER == "aflnet" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh proftpd $NUM_CONTAINERS $OUTDIR aflnet out-proftpd-aflnet "-t 1000+ -m none -P FTP -D 10000 -q 3 -s 3 -E -K -R" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "stateafl" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh proftpd-stateafl $NUM_CONTAINERS $OUTDIR stateafl out-proftpd-stateafl "-t 2000+ -m none -P FTP -D 10000 -q 3 -s 3 -E -K" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "nsfuzz" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh proftpd-nsfuzz $NUM_CONTAINERS $OUTDIR nsfuzz out-proftpd-nsfuzz "-t 1000+ -m none -P FTP -D 10000 -w 10000 -q 3 -s 3 -E -K -R" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "nsfuzz-v" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh proftpd-nsfuzz-v $NUM_CONTAINERS $OUTDIR nsfuzz-v out-proftpd-nsfuzz-v "-t 1000+ -m none -P FTP -D 10000 -q 3 -s 3 -E -K -R" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "aflnwe" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh proftpd $NUM_CONTAINERS $OUTDIR aflnwe out-proftpd-aflnwe "-t 1000+ -m none -D 10000 -K" $TIMEOUT $SKIPCOUNT &
            fi

        fi

        if [[ $TARGET == "pure-ftpd" ]] || [[ $TARGET == "all" ]]
        then

            cd $PFBENCH
            mkdir -p $OUTDIR

            if [[ $FUZZER == "aflnet" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh pure-ftpd $NUM_CONTAINERS $OUTDIR aflnet out-pure-ftpd-aflnet "-t 1000+ -m none -P FTP -D 10000 -q 3 -s 3 -E -K -R" $TIMEOUT $SKIPCOUNT &
                fi

            if [[ $FUZZER == "stateafl" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh pure-ftpd-stateafl $NUM_CONTAINERS $OUTDIR stateafl out-pure-ftpd-stateafl "-t 2000 -m none -P FTP -D 10000 -q 3 -s 3 -E -K" $TIMEOUT $SKIPCOUNT &
                fi
            
            if [[ $FUZZER == "nsfuzz" ]] || [[ $FUZZER == "all" ]]
            then
                # in latest standard, -w 10000 may lead timeout, set to 20000
                # -w [10000/20000/null]
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh pure-ftpd-nsfuzz $NUM_CONTAINERS $OUTDIR nsfuzz out-pure-ftpd-nsfuzz "-t 1000+ -m none -P FTP -D 10000 -w 20000 -q 3 -s 3 -E -K -R" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "nsfuzz-v" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh pure-ftpd-nsfuzz-v $NUM_CONTAINERS $OUTDIR nsfuzz-v out-pure-ftpd-nsfuzz-v "-t 1000+ -m none -P FTP -D 10000 -q 3 -s 3 -E -K -R" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "aflnwe" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh pure-ftpd $NUM_CONTAINERS $OUTDIR aflnwe out-pure-ftpd-aflnwe "-t 1000+ -m none -D 10000 -K" $TIMEOUT $SKIPCOUNT &
                fi

        fi


##### SMTP #####

        if [[ $TARGET == "exim" ]] || [[ $TARGET == "all" ]]
        then

            cd $PFBENCH
            mkdir -p $OUTDIR

            if [[ $FUZZER == "aflnet" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh exim $NUM_CONTAINERS $OUTDIR aflnet out-exim-aflnet "-m none -t 2000+ -P SMTP -D 10000 -q 3 -s 3 -E -K -W 100" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "stateafl" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh exim-stateafl $NUM_CONTAINERS $OUTDIR stateafl out-exim-stateafl "-m none -P SMTP -D 10000 -q 3 -s 3 -E -K -W 50 -t 2000" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "nsfuzz" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh exim-nsfuzz $NUM_CONTAINERS $OUTDIR nsfuzz out-exim-nsfuzz "-m none -t 2000+ -P SMTP -D 10000 -w 50000 -q 3 -s 3 -E -K" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "nsfuzz-v" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh exim-nsfuzz-v $NUM_CONTAINERS $OUTDIR nsfuzz-v out-exim-nsfuzz-v "-m none -t 2000+ -P SMTP -D 10000 -q 3 -s 3 -E -K -W 100" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "aflnwe" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh exim $NUM_CONTAINERS $OUTDIR aflnwe out-exim-aflnwe "-D 10000 -K -W 100" $TIMEOUT $SKIPCOUNT &
            fi

        fi



##### DNS #####

        if [[ $TARGET == "dnsmasq" ]] || [[ $TARGET == "all" ]]
        then

            cd $PFBENCH
            mkdir -p $OUTDIR

            if [[ $FUZZER == "aflnet" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh dnsmasq $NUM_CONTAINERS $OUTDIR aflnet out-dnsmasq-aflnet "-P DNS -D 10000 -K -R -q 3 -s 3 -E" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "stateafl" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh dnsmasq-stateafl $NUM_CONTAINERS $OUTDIR stateafl out-dnsmasq-stateafl "-P DNS -D 10000 -K -R -q 3 -s 3 -E" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "nsfuzz" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh dnsmasq-nsfuzz $NUM_CONTAINERS $OUTDIR nsfuzz out-dnsmasq-nsfuzz "-t 1000+ -m none -P DNS -D 10000 -w 5000 -q 3 -s 3 -E -K -R" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "nsfuzz-v" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh dnsmasq-nsfuzz-v $NUM_CONTAINERS $OUTDIR nsfuzz-v out-dnsmasq-nsfuzz-v "-P DNS -D 10000 -K -R -q 3 -s 3 -E" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "aflnwe" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh dnsmasq $NUM_CONTAINERS $OUTDIR aflnwe out-dnsmasq-aflnwe "-D 10000 -K" $TIMEOUT $SKIPCOUNT &
            fi

        fi


##### RTSP #####

        if [[ $TARGET == "live555" ]] || [[ $TARGET == "all" ]]
        then

            cd $PFBENCH
            mkdir -p $OUTDIR

            if [[ $FUZZER == "aflnet" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh live555 $NUM_CONTAINERS $OUTDIR aflnet out-live555-aflnet "-P RTSP -D 10000 -q 3 -s 3 -E -K -R -t 1000+" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "stateafl" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh live555-stateafl $NUM_CONTAINERS $OUTDIR stateafl out-live555-stateafl "-P RTSP -D 10000 -q 3 -s 3 -E -K -R -t 2000" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "nsfuzz" ]] || [[ $FUZZER == "all" ]]
            then
                # consider -w 5000
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh live555-nsfuzz $NUM_CONTAINERS $OUTDIR nsfuzz out-live555-nsfuzz "-t 1000+ -m none -P RTSP -D 10000 -q 3 -s 3 -E -K -R" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "nsfuzz-v" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh live555-nsfuzz-v $NUM_CONTAINERS $OUTDIR nsfuzz-v out-live555-nsfuzz-v "-P RTSP -D 10000 -q 3 -s 3 -E -K -R -t 1000+" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "aflnwe" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh live555 $NUM_CONTAINERS $OUTDIR aflnwe out-live555-aflnwe "-D 10000 -K -t 1000+" $TIMEOUT $SKIPCOUNT &
            fi

        fi


##### SIP #####

        if [[ $TARGET == "kamailio" ]] || [[ $TARGET == "all" ]]
        then

            cd $PFBENCH
            mkdir -p $OUTDIR

            if [[ $FUZZER == "aflnet" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 10 
                ${PFBENCH}/profuzzbench_exec_common.sh kamailio $NUM_CONTAINERS $OUTDIR aflnet out-kamailio-aflnet "-m none -t 3000+ -P SIP -l 5061 -D 50000 -q 3 -s 3 -E -K" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "stateafl" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 10 
                ${PFBENCH}/profuzzbench_exec_common.sh kamailio-stateafl $NUM_CONTAINERS $OUTDIR stateafl out-kamailio-stateafl "-m none -t 3000+ -P SIP -l 5061 -W 10 -D 50000 -q 3 -s 3 -E -K" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "nsfuzz" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 10 
                ${PFBENCH}/profuzzbench_exec_common.sh kamailio-nsfuzz $NUM_CONTAINERS $OUTDIR nsfuzz out-kamailio-nsfuzz "-m none -t 1000+ -P SIP -l 5061 -D 10000 -w 10000 -q 3 -s 3 -E -K" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "nsfuzz-v" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 10 
                ${PFBENCH}/profuzzbench_exec_common.sh kamailio-nsfuzz-v $NUM_CONTAINERS $OUTDIR nsfuzz-v out-kamailio-nsfuzz-v "-m none -t 3000+ -P SIP -l 5061 -D 50000 -q 3 -s 3 -E -K" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "aflnwe" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 10 
                ${PFBENCH}/profuzzbench_exec_common.sh kamailio $NUM_CONTAINERS $OUTDIR aflnwe out-kamailio-aflnwe "-m none -t 3000+ -D 50000 -K" $TIMEOUT $SKIPCOUNT &
            fi

        fi


##### SSH #####

        if [[ $TARGET == "openssh" ]] || [[ $TARGET == "all" ]]
        then

            cd $PFBENCH
            mkdir -p $OUTDIR

            if [[ $FUZZER == "aflnet" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh openssh $NUM_CONTAINERS $OUTDIR aflnet out-openssh-aflnet "-P SSH -D 10000 -q 3 -s 3 -E -K -R -W 10" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "stateafl" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh openssh-stateafl $NUM_CONTAINERS $OUTDIR stateafl out-openssh-stateafl "-P SSH -D 10000 -q 3 -s 3 -E -K -W 10 -l 30000 -e 20000 -t 2000" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "nsfuzz" ]] || [[ $FUZZER == "all" ]]
            then
                # -w 10000 may lead to seed timeout?
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh openssh-nsfuzz $NUM_CONTAINERS $OUTDIR nsfuzz out-openssh-nsfuzz "-m none -t 1000+ -P SSH -D 10000 -w 50000 -q 3 -s 3 -E -R -K" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "nsfuzz-v" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh openssh-nsfuzz-v $NUM_CONTAINERS $OUTDIR nsfuzz-v out-openssh-nsfuzz-v "-P SSH -D 10000 -q 3 -s 3 -E -K -R -W 10" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "aflnwe" ]] || [[ $FUZZER == "all" ]]
                then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh openssh $NUM_CONTAINERS $OUTDIR aflnwe out-openssh-aflnwe "-D 10000 -K -W 10" $TIMEOUT $SKIPCOUNT &
            fi

        fi


##### TLS #####

        if [[ $TARGET == "openssl" ]] || [[ $TARGET == "all" ]]
        then

            cd $PFBENCH
            mkdir -p $OUTDIR

            if [[ $FUZZER == "aflnet" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh openssl $NUM_CONTAINERS $OUTDIR aflnet out-openssl-aflnet "-P TLS -D 10000 -q 3 -s 3 -E -K -R -W 100 -m none" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "stateafl" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh openssl-stateafl $NUM_CONTAINERS $OUTDIR stateafl out-openssl-stateafl "-P TLS -D 10000 -q 3 -s 3 -E -K -R -W 100 -m none -t 2000" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "nsfuzz" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                # sync-reduce: -w 4000
                ${PFBENCH}/profuzzbench_exec_common.sh openssl-nsfuzz $NUM_CONTAINERS $OUTDIR nsfuzz out-openssl-nsfuzz "-P TLS -m none -t 2000+ -D 10000 -w 10000 -q 3 -s 3 -E -K -R" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "nsfuzz-v" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh openssl-nsfuzz-v $NUM_CONTAINERS $OUTDIR nsfuzz-v out-openssl-nsfuzz-v "-P TLS -D 10000 -q 3 -s 3 -E -K -R -W 100 -m none" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "aflnwe" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh openssl $NUM_CONTAINERS $OUTDIR aflnwe out-openssl-aflnwe "-D 10000 -K -W 100 -m none" $TIMEOUT $SKIPCOUNT &
            fi

        fi


##### DTLS #####

        if [[ $TARGET == "tinydtls" ]] || [[ $TARGET == "all" ]]
        then

            cd $PFBENCH
            mkdir -p $OUTDIR

            if [[ $FUZZER == "aflnet" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                # fuzz campaign with -m none added
                ${PFBENCH}/profuzzbench_exec_common.sh tinydtls $NUM_CONTAINERS $OUTDIR aflnet out-tinydtls-aflnet "-P DTLS12 -D 10000 -q 3 -s 3 -E -K -W 30" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "stateafl" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh tinydtls-stateafl $NUM_CONTAINERS $OUTDIR stateafl out-tinydtls-stateafl "-P DTLS12 -D 10000 -q 3 -s 3 -E -K -W 30 -t 1000" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "nsfuzz" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh tinydtls-nsfuzz $NUM_CONTAINERS $OUTDIR nsfuzz out-tinydtls-nsfuzz "-t 1000+ -m none -P DTLS12 -D 10000 -w 1000 -q 3 -s 3 -E -K" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "nsfuzz-v" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh tinydtls-nsfuzz-v $NUM_CONTAINERS $OUTDIR nsfuzz-v out-tinydtls-nsfuzz-v "-P DTLS12 -D 10000 -q 3 -s 3 -E -K -W 30" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "aflnwe" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh tinydtls $NUM_CONTAINERS $OUTDIR aflnwe out-tinydtls-aflnwe "-D 10000 -K -W 30" $TIMEOUT $SKIPCOUNT &
            fi

        fi

##### DICOM #####

        if [[ $TARGET == "dcmtk" ]] || [[ $TARGET == "all" ]]
        then

            cd $PFBENCH
            mkdir -p $OUTDIR

            if [[ $FUZZER == "aflnet" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh dcmtk $NUM_CONTAINERS $OUTDIR aflnet out-dcmtk-aflnet "-P DICOM -D 10000 -E -K -m none -t 1000+" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "stateafl" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh dcmtk-stateafl $NUM_CONTAINERS $OUTDIR stateafl out-dcmtk-stateafl "-P DICOM -D 10000 -E -K -m none  -W 10 -t 1000+" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "nsfuzz" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                # erase -w may be better
                ${PFBENCH}/profuzzbench_exec_common.sh dcmtk-nsfuzz $NUM_CONTAINERS $OUTDIR nsfuzz out-dcmtk-nsfuzz "-m none -P DICOM -D 10000 -E -K -R -t 2000+" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "nsfuzz-v" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh dcmtk-nsfuzz-v $NUM_CONTAINERS $OUTDIR nsfuzz-v out-dcmtk-nsfuzz-v "-P DICOM -D 10000 -E -K -m none -t 1000+" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "aflnwe" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh dcmtk $NUM_CONTAINERS $OUTDIR aflnwe out-dcmtk-aflnwe "-D 10000 -K" $TIMEOUT $SKIPCOUNT &
            fi

        fi


##### DAAPD #####

        if [[ $TARGET == "forked-daapd" ]] || [[ $TARGET == "all" ]]
        then

            cd $PFBENCH
            mkdir -p $OUTDIR

            if [[ $FUZZER == "aflnet" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh forked-daapd $NUM_CONTAINERS $OUTDIR aflnet out-forked-daapd-aflnet "-P HTTP -D 200000 -m none -t 3000+ -q 3 -s 3 -E -K" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "stateafl" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh forked-daapd-stateafl $NUM_CONTAINERS $OUTDIR stateafl out-forked-daapd-stateafl "-P HTTP -D 200000 -m none -t 3000+ -q 3 -s 3 -E -K" $TIMEOUT $SKIPCOUNT &
            fi

            # -w [10000/30000/50000/100000]
            # -t [1000+/2000+/3000+]
            # -R [w/w.o]
            # in eval standard, -w 30000/50000 may lead to the first init seed timeout
            # but seems could get a better overall result?
            if [[ $FUZZER == "nsfuzz" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh forked-daapd-nsfuzz $NUM_CONTAINERS $OUTDIR nsfuzz out-forked-daapd-nsfuzz "-P HTTP -m none -t 2000+ -q 3 -s 3 -E -K -R" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "nsfuzz-v" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh forked-daapd-nsfuzz-v $NUM_CONTAINERS $OUTDIR nsfuzz-v out-forked-daapd-nsfuzz-v "-P HTTP -D 200000 -m none -t 3000+ -q 3 -s 3 -E -K" $TIMEOUT $SKIPCOUNT &
            fi

            if [[ $FUZZER == "aflnwe" ]] || [[ $FUZZER == "all" ]]
            then
                sleep 1
                ${PFBENCH}/profuzzbench_exec_common.sh forked-daapd $NUM_CONTAINERS $OUTDIR aflnwe out-forked-daapd-aflnwe "-D 200000 -m none -t 3000+ -K" $TIMEOUT $SKIPCOUNT &
            fi

        fi

        if [[ $TARGET == "all" ]]
        then
            # Quit loop -- all fuzzers and targets have already been executed
            exit
        fi

    done
done

