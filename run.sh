#!/bin/bash

numofexp=$1

home=`pwd`
result_dir=$home/$2

mkdir -p $result_dir

threads="1"
#tests="eval_scan_64"
tests="eval_scan_64 eval_scan_512 eval_scan_4k eval_scan_32k"
index_type="LSM BTREE BASE INMEM"
prefetch_ena="TRUE FALSE"
for exp_id in $( seq 1 $numofexp )
do
	for testfile in $tests
	do
		for index in $index_type
		do
			export INDEX_TYPE=$index
			if [ "$index" == "BASE" ]; then
				sed -i 's/operationcount=.*/operationcount=100/' workloads/eval_scan_*
			else
				sed -i 's/operationcount=.*/operationcount=100000/' workloads/eval_scan_*
			fi
			for prefetch in $prefetch_ena
			do
				export PREFETCH_ENA=$prefetch

				result_txt=$result_dir/${testfile}_${index}_${prefetch}_${exp_id}
				# clean file if existed
				echo "" > $result_txt
				for numofthreads in $threads
				do
					echo ===== $numofthreads threads ====== >> $result_txt
					echo "" >> $result_txt

					# format kvssd
					nvme format /dev/nvme0n1
					echo "format /dev/nvme0n1 success"
						
					# ycsb load
					./bin/ycsb load kvrangedb -s -P workloads/$testfile -threads $numofthreads > tmp.txt 
					echo $testfile results >> $result_txt
					echo load >> $result_txt
					printf "load_tp: " >> $result_txt
					cat tmp.txt|grep OVERALL|grep Throughput|awk '{print $3}' >> $result_txt
					printf "load_lat: " >> $result_txt
					cat tmp.txt|grep AverageLatency|grep INSERT|awk '{print $3}' >> $result_txt
					
					sleep 3
					# ycsb run scan 100
					sed -i 's/maxscanlength.*/maxscanlength=100/' workloads/$testfile

					./bin/ycsb run kvrangedb -s -P workloads/$testfile -threads $numofthreads > tmp.txt  
					echo "run scan 100" >> $result_txt
					printf "run_tp: " >> $result_txt
					cat tmp.txt|grep OVERALL|grep Throughput|awk '{print $3}' >> $result_txt
					printf "scan_lat: " >> $result_txt
					cat tmp.txt|grep AverageLatency|grep SCAN|awk '{print $3}' >> $result_txt
					rm tmp.txt

					sleep 3
					# ycsb run scan 1 (seek)
					sed -i 's/maxscanlength.*/maxscanlength=1/' workloads/$testfile

					./bin/ycsb run kvrangedb -s -P workloads/$testfile -threads $numofthreads > tmp.txt  
					echo "run scan 1" >> $result_txt
					printf "run_tp: " >> $result_txt
					cat tmp.txt|grep OVERALL|grep Throughput|awk '{print $3}' >> $result_txt
					printf "scan_lat: " >> $result_txt
					cat tmp.txt|grep AverageLatency|grep SCAN|awk '{print $3}' >> $result_txt
					rm tmp.txt
						
					echo "" >> $result_txt

					rm -rf *.log # clean up files
				done
			done
		done
	done
done

echo testing completed
