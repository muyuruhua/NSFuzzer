# about 6+3 mins

# coding=utf-8
import argparse
import tarfile
import os
import re
import json
import time
from pandas import read_csv
import pandas as pd
import csv

aflnet = "aflnet"
aflnwe = "aflnwe"
stateafl = "stateafl"
nsfuzz_v = "nsfuzz-v"
nsfuzz = "nsfuzz"
fuzzers = [aflnet, aflnwe, stateafl, nsfuzz_v, nsfuzz]

MAX_RUNS = 6 # used to setup class

class result_data_cls():
    def __init__(self) -> None:
        self.paths = None
        self.map_density = None
        self.total_execs = None
        self.coverage = None
        self.average_speed = None
        self.stability = None
        self.unique_crashes = None
        self.vertex = None
        self.edge = None
        self.sv_count = None



# get all the files
def get_full_file_path(file_dir):
    L=[]
    for root,dirs,files in os.walk(file_dir):
        for file in files:
            L.append(os.path.join(root, file))
    return L

def get_file_name(file_dir):
    L=[]
    for root,dirs,files in os.walk(file_dir):
        for file in files:
            L.append(file)
    return L


# unzip
def un_tar(file_names, file_path):
    file_name=file_names
    tar = tarfile.open(file_path+"/"+file_name)
    # rename the folder
    if file_name.find(".tar.gz")!=-1:
        file_name=file_name.replace(".tar.gz", "")
    else:
        pass
    names = tar.getnames()
    # unzip recursively
    for name in names:
        if name.find("fuzzer_stats")!=-1:
            tar.extract(name, file_path)
            os.system("mv " + name + " " + name + '_' + file_name)
        if name.find("cov_over_time")!=-1:
            tar.extract(name, file_path)
            os.system("mv " + name + " " + name[:-4] + '_' + file_name)
        if name.find("ipsm.dot")!=-1:
            tar.extract(name, file_path)
            os.system("mv " + name + " " + name[:-4] + '_' + file_name)
    return

def get_digit(line):
    nums = [int(s) for s in line.split() if s.isdigit()]
    if len(nums) != 1:
        return -1
    return nums[0]

def get_num(line):
    datas = re.findall(r"\d+\.?\d*",line)
    if len(datas) != 1:
        return -1
    return datas[0]

# collect data
def extract_stats_data(file_name, runtime):
    
    result = result_data_cls()

    for line in open(file_name, "r"):
        if line.find("paths_total") != -1:
            result.paths = int(get_num(line))
        elif line.find('bitmap_cvg') != -1:
            result.map_density = float(get_num(line))
        elif line.find("execs_done") != -1:
            result.total_execs = int(get_num(line))
            result.average_speed = result.total_execs/runtime
        elif line.find("stability") != -1:
            result.stability = float(get_num(line))
        elif line.find("unique_crashes") != -1:
            result.unique_crashes = int(get_num(line))

    return result

# extract gcov
def extract_cov_data(file_name):
    with open(file_name, 'r') as csvfile:
        lines = csvfile.readlines()
        targetline = lines[-1]
        num = int(targetline.split(',')[-1][:-1])
        return num

# extract state & vertex
def extract_ipsm(file_name):
    # print('--------------------------')
    state_set = set()
    vertex_set = set()
    with open(file_name, 'r') as dot:
        for line in dot:
            if re.search(r'\s*(-*\d+)\s->\s(-*\d+).*', line):
                out = re.findall(r'\s*(-*\d+)\s->\s(-*\d+).*', line)
                # print(out)
                state_from = out[0][0]
                state_to = out[0][1]
                if state_from not in state_set:
                    # print(state_from)
                    state_set.add(state_from)
                if state_to not in state_set:
                    # print(state_to)
                    state_set.add(state_to)
                edge = state_from + '->' + state_to
                if edge not in vertex_set:
                    vertex_set.add(edge)
    return int(len(state_set)), int(len(vertex_set))

# extract state variable range
def extract_sv(file_name):
    with open(file_name, 'r') as f:
        sv_data = json.load(f)
    return sv_data["Total"]

# get the fuzzer name from the string
def get_fuzzer_name(filename):
    if filename.find("aflnet") != -1:
        return "aflnet"
    if filename.find("aflnwe") != -1:
        return "aflnwe"
    if filename.find("stateafl") != -1:
        return "stateafl"
    if filename.find("nsfuzz-v") != -1:
        return "nsfuzz-v"
    if filename.find("nsfuzz") != -1:
        return "nsfuzz"

# get the run id
def get_run_id(filename):
    for i in range(1, MAX_RUNS+1):
        if filename.find("_" + str(i)) != -1:
            return i


def collect_data(target, runs, runtime):

    # untar .tar.gz files
    file_dir = os.getcwd() + "/" + target
    files = os.listdir(file_dir)
    for file in files:
        if file.find('.tar.gz') != -1:
            if os.path.exists("./" + file[:-9]):
                os.system("rm -r " + "./" + file[:-9] + " > /dev/null 2>&1")
            os.system("tar -zxvf " + file_dir + '/' + file + " > /dev/null 2>&1")
            if os.path.exists(file_dir + '/' + file[:-7]):
                os.system("rm -r " + file_dir + '/' + file[:-7] + " > /dev/null 2>&1")
            os.system("mv " + file[:-9] + " " + file_dir + '/' + file[:-7] + " > /dev/null 2>&1")

    # collecting datas

    # initialize the result dict
    target_result = {"aflnet":[], "aflnwe":[], "stateafl":[], "nsfuzz-v":[], "nsfuzz":[]}
    for key in target_result.keys():
        for i in range(runs):
            target_result[key].append({
        'paths': -1,
        'map_density': -1,
        'total_execs': -1,
        'average_speed': -1,
        'stability': -1,
        'unique_crashes': -1,
        'coverage': -1,
        'vertex': -1,
        'edge': -1,
        'time_to_crash': -1
    })
    
    # for root,dirs,files in os.walk(file_dir):
    files = [f for f in os.listdir(file_dir) if os.path.isfile(os.path.join(file_dir, f))]
    dirs  = [f for f in os.listdir(file_dir) if not os.path.isfile(os.path.join(file_dir, f))]
    # process files in extractd folders
    for dir in dirs:
        fuzzer = get_fuzzer_name(dir)
        try:
            id = get_run_id(dir) - 1
        except:
            continue
        if id >= runs:
            continue
        # for _,_,subfiles in os.walk(file_dir + '/' + dir):
        subfiles = [f for f in os.listdir(file_dir + '/' + dir) if os.path.isfile(os.path.join(file_dir + '/' + dir, f))]
        for subfile in subfiles:
            subfile_fullpath = file_dir + '/' + dir + '/' + subfile
            if subfile.find('fuzzer_stats') != -1:
                stats = extract_stats_data(subfile_fullpath, runtime)
                target_result[fuzzer][id]['paths'] = stats.paths
                target_result[fuzzer][id]['map_density'] = stats.map_density
                target_result[fuzzer][id]['total_execs'] = stats.total_execs
                target_result[fuzzer][id]['average_speed'] = round(stats.average_speed, 2)
                target_result[fuzzer][id]['stability'] = stats.stability
                target_result[fuzzer][id]['unique_crashes'] = stats.unique_crashes
            if subfile.find('cov_over_time') != -1:
                target_result[fuzzer][id]['coverage'] = extract_cov_data(subfile_fullpath)
            if subfile.find('ipsm') != -1:
                target_result[fuzzer][id]['vertex'], target_result[fuzzer][id]['edge'] = extract_ipsm(subfile_fullpath)

            
    # process files in root
    for file  in files:            
        fuzzer = get_fuzzer_name(file)
        try:
            id = get_run_id(file) - 1
        except:
            continue
        if id >= runs:
            continue
        file_fullpath = file_dir + '/' + file
        if file.find('sv_range') != -1 and file.find('.json') != -1:
            target_result[fuzzer][id]['sv_count'] = extract_sv(file_fullpath)

    # clear folders
    files = os.listdir(file_dir)
    for file in files:
        if not os.path.isfile(os.path.join(file_dir, file)):
            os.system("rm -rf " + os.path.join(file_dir, file))

    return target_result


def parse_target(csv_file, put, runs, cut_off, step):
    import time
    #Read the results
    df = read_csv(csv_file)
    #Calculate the mean of code coverage
    #Store in a list first for efficiency
    mean_list = []

    for subject in [put]:
        #for fuzzer in ['aflnet', 'aflnwe']:
        for fuzzer in fuzzers:
            for cov_type in ['b_abs', 'b_per', 'l_abs', 'l_per']:
                #get subject & fuzzer & cov_type-specific dataframe
                df1 = df[(df['subject'] == subject) & 
                                (df['fuzzer'] == fuzzer) & 
                                (df['cov_type'] == cov_type)]
                mean_list.append((subject, fuzzer, cov_type, 0, 0.0))
                for t in range(1, cut_off + 1, step):
                    cov_total = 0
                    run_count = 0
                    for run in range(1, runs + 1, 1):
                        #get run-specific data frame
                        
                        df2 = df1[df1['run'] == run]

                        
                        #get the starting time for this run
                        start = df2.iloc[0, 0]

                        #get all rows given a cutoff time
                        df3 = df2[df2['time'] <= start + t*60]

                        
                        #update total coverage and #runs
                        cov_total += int(df3.tail(1).iloc[0, 5])
                        run_count += 1

                    
                    #add a new row
                    mean_list.append((subject, fuzzer, cov_type, t, cov_total / run_count))
                
    #Convert the list to a dataframe
    mean_df = pd.DataFrame(mean_list, columns = ['subject', 'fuzzer', 'cov_type', 'time', 'cov'])
    mean_df.drop(mean_df.loc[mean_df['cov_type'] != 'b_abs'].index, inplace=True)

    return mean_df


if __name__ == '__main__':
    start_time = time.time()

    parser = argparse.ArgumentParser()    
    parser.add_argument('-t','--runtime',type=int,required=True,help="evaluation runtime")
    parser.add_argument('-r','--runs',type=int,required=True,help="run times for each target_fuzzer evaluation")
    parser.add_argument('-o','--outfolder',type=str,required=True,help="output file name")
    args = parser.parse_args()

    # create result folder
    if not os.path.exists("./" + args.outfolder):
        os.system("mkdir " + "./" + args.outfolder)


    # targets = ['forked-daapd', 'dcmtk', 'dnsmasq', 'tinydtls', 'bftpd', 'lightftp', 'proftpd', 'pure-ftpd', 'live555', 'kamailio', 'exim', 'openssh', 'openssl']
    targets = [
        'LightFTP'.lower(), 
        'Bftpd'.lower(), 
        'Pure-FTPd'.lower(), 
        'ProFTPD'.lower(), 
        'Dnsmasq'.lower(), 
        'TinyDTLS'.lower(), 
        'Exim'.lower(), 
        'Kamailio'.lower(), 
        'OpenSSH'.lower(), 
        'OpenSSL'.lower(),
        'Forked-daapd'.lower(), 
        'Live555'.lower(),
        'Dcmtk'.lower()]

    database = dict()
    # add data one by one
    for target in targets:
        # print("Extracting data of " + target + "...")
        data = collect_data(target, args.runs, args.runtime)
        database[target] = data

    # save database to json file
    print("Saving extracted data...")
    js = json.dumps(database)
    file = open(args.outfolder + '/database-all.json', 'w')
    file.write(js)
    file.close()
    end_time = time.time()
    print("Finished creating database-all.json. Timecost: " + str(end_time - start_time) + '.')
    start_time = time.time()
    

    # process cov data for each target

    for target in targets:
        print('Processing cov data of ' + target + '.')
        lines_out = []
        for fuzzer in fuzzers:
            for i in range(args.runs):
                outfolder = 'out-' + target + '-' + fuzzer
                os.system('tar -axf ' + './' + target + '/' + outfolder + '_' + str(i+1) + '.tar.gz ' + outfolder + '/cov_over_time.csv')
                # open file
                with open(outfolder + '/cov_over_time.csv', 'r') as csvfile:
                    lines_in = csvfile.readlines()
                    for line in lines_in[1:]:
                        line = line.split(',')
                        lines_out.append([line[0], target, fuzzer, i+1, 'l_per', line[1]])
                        lines_out.append([line[0], target, fuzzer, i+1, 'l_abs', line[2]])
                        lines_out.append([line[0], target, fuzzer, i+1, 'b_per', line[3]])
                        lines_out.append([line[0], target, fuzzer, i+1, 'b_abs', line[4][:-1]])
                os.system('rm -rf ' + outfolder)
        with open('./' + target + '/results_' + target + '.csv', 'w', newline='') as csvfile:
            writer = csv.writer(csvfile)   
            writer.writerow(["time","subject","fuzzer","run","cov_type","cov"])
            for line in lines_out:                 
                writer.writerow(line)

    # get unique cov file
    print('Collecting cov data of all targets.')
    runtime = int(args.runtime/60) # from s to m
    if len(targets) >=2 :
        target = targets[0]
        df = parse_target('./' + target + '/results_' + target + '.csv', target, args.runs, runtime, 10)
        for target in targets[1:]:
            # print("Collecting from " + target + '.')
            df = pd.concat([df, parse_target('./' + target + '/results_' + target + '.csv', target, args.runs, runtime, 10)])
    else:
        target = targets[0]
        df = parse_target('./' + target + '/results_' + target + '.csv', target, args.runs, runtime, 10)
    df.to_csv(args.outfolder + '/coverage-all.csv')


    end_time = time.time()
    print("Finished creating coverage-all.csv. Timecost: " + str(end_time - start_time) + '.')