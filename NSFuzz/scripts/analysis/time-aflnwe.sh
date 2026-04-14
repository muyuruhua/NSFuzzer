
#!/bin/bash
TARGET=$1

#rm -r $TARGET
#tar -zxvf $TARGET"_1.tar.gz" > null 2>&1

#read start time
stats=`sed -n 1p "$TARGET/fuzzer_stats" | awk '{print $3}'`

#read first cash 
dir=`ls $TARGET/crashes/`
DIR_PATH="$TARGET/crashes/"
min=`date +%s`
for f in $dir
do
    FILE_NAME=${DIR_PATH}${f}
#    echo $FILE_NAME
    a=`stat -c %Y $FILE_NAME`
    if [ $min > $a ]
    then
#        echo "file is earlier:$FILE_NAME time:$a"
	min=$a
    fi
done

#delete file
rm "1"*  > /dev/null 2>&1
rm -rf "$TARGET"  > /dev/null 2>&1

#print result
passed=`expr ${min} - ${stats}`
#echo "First cash:${min}; start at:${stats}; time passed: ${passed} "
echo ${passed}

