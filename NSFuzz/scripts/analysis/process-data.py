
# coding=utf-8
import argparse
import os
import json
import csv
from pandas import read_csv
from matplotlib import pyplot as plt
import numpy as np
from matplotlib.backends.backend_pdf import PdfPages
from matplotlib import ticker

aflnet = "aflnet"
aflnwe = "aflnwe"
stateafl = "stateafl"
nsfuzz_v = "nsfuzz-v"
nsfuzz = "nsfuzz"
fuzzers = [aflnet, aflnwe, stateafl, nsfuzz_v, nsfuzz]

### common sets for plotting
font_size = 110
      
params = {
  'mathtext.default': 'regular', 
  'xtick.labelsize': font_size-20,
  'ytick.labelsize': font_size-20,
  # 'axes.labelsize': 20
}
font_title = {#'family': 'Arial',   # serif
    'style': 'normal',   # 'italic',
    'weight': 'bold',
    'size': font_size,
    }

font_label = {#'family': 'Arial',   # serif  #Arial Unicode MS中文
              'style': 'normal',   # 'italic',
              'weight': 'bold',
              'size': font_size,
              }

color_map = {'aflnet': 'tomato',
            'aflnwe': 'darkorange',
            'nsfuzz': 'olivedrab',
            'nsfuzz-v': 'skyblue',
            'stateafl': 'plum'
            }
            
# targets = [
# 'Dcmtk', 
# 'Forked-daapd', 
# 'Dnsmasq', 
# 'TinyDTLS', 
# 'Bftpd', 
# 'LightFTP', 
# 'ProFTPD', 
# 'Pure-FTPd', 
# 'Live555', 
# 'Kamailio', 
# 'Exim', 
# 'OpenSSH', 
# 'OpenSSL']

targets = [
'LightFTP', 
'Bftpd', 
'Pure-FTPd', 
'ProFTPD', 
'Dnsmasq', 
'TinyDTLS', 
'Exim', 
'Kamailio', 
'OpenSSH', 
'OpenSSL',
'Live555', 
'Forked-daapd', 
'Dcmtk']

fuzzer_name_map = {
'aflnet' : 'AFLNet',
'aflnwe' : 'AFLNwe',
'stateafl' : 'StateAFL',
'nsfuzz-v' : 'NSFuzz-V',
'nsfuzz' : 'NSFuzz'}

target_name_map = {}
for target in targets:
    target_name_map[target.lower()] = target


def format_improvement(num):
    if num >= 0:
        return "+" + format(100*num, ".2f") + "%"
    else:
        return "-" + format(-100*num, ".2f") + "%"


def plot_bars(data_dict, fig_file_name, ylabel):
    # data format: {target1:{fuzzer1:content,...},...}
    selected_fuzzers = data_dict['bftpd'].keys()
    labels = selected_fuzzers
    labels = [fuzzer_name_map[x.lower()] for x in labels] # get the official name of the fuzzer
    colors = [color_map[x.lower()] for x in labels]
    fig = plt.figure(figsize=(100, 60))

    for i in range(len(targets)):
        target = targets[i].lower()
        data = [data_dict[target][x] for x in selected_fuzzers]
        try:
            data = [float(x) for x in data] # str to int
        except:
            data = [0] * len(data)
        plt.subplot(3, 5, i+1)
        bars = plt.bar(range(len(data)), data, color=colors, width=0.5)
        plt.xticks(range(len(data)), labels, fontsize=30)
        plt.xlabel("Fuzzers", font_label)
        plt.ylabel(ylabel, font_label)
        plt.title(targets[i], font_title)
        plt.grid(linewidth=3, axis='y')
        plt.ylim(bottom=0, top=max(data)*1.2) 
    # labels and other settings
    fig.legend(bars, labels, loc="lower center", bbox_to_anchor=(0.8, 0.15), fontsize=60, shadow=True, framealpha=1)
    plt.subplots_adjust(left=None, bottom=None, right=None,
                        top=None, wspace=0.5, hspace=0.5)
    plt.savefig(fig_file_name)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()    
    parser.add_argument('-f','--filename',type=str,required=True,help="database file")
    parser.add_argument('-cov','--cov_file',type=str,required=True,help="cov file")
    parser.add_argument('-o','--outfolder',type=str,required=True,help="output folder to store results")
    parser.add_argument('-t','--runtime',type=int,required=True,help="evaluation runtime")
    parser.add_argument('-r','--runs',type=int,required=True,help="run times for each target_fuzzer evaluation")
    args = parser.parse_args()

    
    ################################## load data ##################################
    with open(args.filename,'r') as f:
        database = json.load(f)    
    print("Database loaded.")
    
    ################################## RQ1: get results of throughput improvement #################################
    fuzzers = [aflnet, aflnwe, stateafl, nsfuzz]
    throughput = dict()
    for target in database.keys():
        target_throughput = dict()
        for fuzzer in fuzzers:
            target_fuzzer_throughput = [x['average_speed'] for x in database[target][fuzzer]]
            target_throughput[fuzzer] = sum(target_fuzzer_throughput) / len(target_fuzzer_throughput)
        throughput[target] = target_throughput

    # calulate throughput improvement
    throughput_improvement = dict()
    for target in throughput.keys():
        target_throughput = dict()
        for fuzzer in throughput[target].keys():
            if fuzzer == aflnet:
                target_throughput[fuzzer] = format(throughput[target][fuzzer],'.2f')
            else:
                target_throughput[fuzzer] = format_improvement(throughput[target][fuzzer] / throughput[target][aflnet] - 1)
        throughput_improvement[target] = target_throughput
    # write to csv file
    with open("./" + args.outfolder + '/table-throughput-improvement.csv', 'w', newline='') as file:
        writer = csv.writer(file)
        writer.writerow([" "] + [fuzzer_name_map[x] for x in fuzzers])
        for target in throughput_improvement.keys():
            writer.writerow([target_name_map[target]] + [throughput_improvement[target][x] for x in fuzzers])

        # average improvement
        item = ['Average']
        for fuzzer in fuzzers:
            average = 0
            for target in targets:
                target = target.lower()
                if fuzzer == aflnet:
                    average += throughput[target][fuzzer]
                else:
                    average += throughput[target][fuzzer]  / throughput[target][aflnet] - 1
            average /= len(targets)
            if fuzzer == aflnet:
                item.append(format(average, '.2f'))
            else:
                item.append(format_improvement(average))
        writer.writerow(item)


    print("Finished: " + "./" + args.outfolder + '/table-throughput-improvement.csv')

    fuzzers = [aflnet, aflnwe, stateafl, nsfuzz_v, nsfuzz]

    ################################## RQ2: value of vertex and edges num ##################################
    fuzzers = [aflnet, aflnwe, stateafl, nsfuzz]

    sm_dict = dict()
    for target in database.keys():
        target = target.lower()
        target_state_model = {'aflnet':dict(), 'stateafl':dict(), 'nsfuzz':dict()}
        for fuzzer in fuzzers:
            if fuzzer == 'aflnwe':
                continue
            target_state_model[fuzzer]['vertex'] = int(sum(database[target][fuzzer][x]['vertex'] for x in range(args.runs)) / args.runs)
            target_state_model[fuzzer]['edge'] = int(sum(database[target][fuzzer][x]['edge'] for x in range(args.runs)) / args.runs)
        sm_dict[target] = target_state_model

    with open("./" + args.outfolder + '/table-state-model-vertex-edge.csv', 'w', newline='') as file:
        writer = csv.writer(file)
        writer.writerow(['', 'AFLNet', 'AFLNet', 'StateAFL', 'StateAFL', 'NSFuzz', 'NSFuzz'])
        writer.writerow(['', 'Vertexes', 'Edges', 'Vertexes', 'Edges', 'Vertexes', 'Edges'])
        for target in sm_dict.keys():
            item = [target_name_map[target]]
            for fuzzer in sm_dict[target].keys():
                item.append(sm_dict[target][fuzzer]['vertex'])
                item.append(sm_dict[target][fuzzer]['edge'])
            writer.writerow(item)
    
    print("Finished: " + "./" + args.outfolder + '/table-state-model-vertex-edge.csv')

    fuzzers = [aflnet, aflnwe, stateafl, nsfuzz_v, nsfuzz]

    ################################## RQ3: get results of code coverage improvement ##################################
    code_coverage = dict()
    for target in database.keys():
        target_coverage = dict()
        for fuzzer in database[target].keys():
            target_fuzzer_coverage = [x['coverage'] for x in database[target][fuzzer]]
            target_coverage[fuzzer] = sum(target_fuzzer_coverage) / len(target_fuzzer_coverage)
        code_coverage[target] = target_coverage

    # calulate coverage improvement
    code_coverage_improvement = dict()
    for target in code_coverage.keys():
        target_code_coverage = dict()
        for fuzzer in code_coverage[target].keys():
            if fuzzer == aflnet:
                target_code_coverage[fuzzer] = format(code_coverage[target][fuzzer], '.2f')
            else:
                target_code_coverage[fuzzer] = format_improvement(code_coverage[target][fuzzer] / code_coverage[target][aflnet] - 1)
        code_coverage_improvement[target] = target_code_coverage
    # write to csv file
    with open("./" + args.outfolder + '/table-code-coverage-improvement.csv', 'w', newline='') as file:
        writer = csv.writer(file)
        writer.writerow([" "] + [fuzzer_name_map[x] for x in fuzzers])
        for target in code_coverage_improvement.keys():
            writer.writerow([target_name_map[target]] + [code_coverage_improvement[target][x] for x in fuzzers])

        # average improvement
        item = ['Average']
        for fuzzer in fuzzers:
            average = 0
            for target in targets:
                target = target.lower()
                if fuzzer == aflnet:
                    average += code_coverage[target][fuzzer]
                else:
                    average += code_coverage[target][fuzzer]  / code_coverage[target][aflnet] - 1
            average /= len(targets)
            if fuzzer == aflnet:
                item.append(format(average, '.2f'))
            else:
                item.append(format_improvement(average))
        writer.writerow(item)
    print("Finished: " + "./" + args.outfolder + '/table-code-coverage-improvement.csv')

    ################################# RQ3: plot code coverage over time ##################################
    ylims = {
        'forked-daapd' : [1200, 2800],
        'dcmtk' : [2200, 2750],
        'dnsmasq' : [900, 1250],
        'tinydtls' : [100, 650],
        'bftpd' : [380, 490], 
        'lightftp' : [300, 420], 
        'proftpd' : [3800, 5400], 
        'pure-ftpd' : [400, 1400], 
        'live555' : [2700, 3050], 
        'kamailio' : [5000, 11000], 
        'exim' : [800, 4500], 
        'openssh' : [3000, 3700], 
        'openssl' : [7500, 10000]
    }
    sqs = {
        'lightftp' : 1, 
        'bftpd' : 2, 
        'pure-ftpd' : 3, 
        'proftpd' : 4, 
        'dnsmasq' : 5,
        'tinydtls' : 6,
        'exim' : 7, 
        'kamailio' : 8, 
        'openssh' : 9, 
        'openssl' : 10,
        'forked-daapd' : 11,
        'live555' : 12, 
        'dcmtk' : 13
    }

    with PdfPages("./" + args.outfolder + "/fig-coverage.pdf") as pdf:
        plt.rcParams.update(params)
        fig = plt.figure(figsize=(120, 70))
        labels = []
        df = read_csv(args.cov_file)
        line_width = 20
        bwith = 0.01
        for key, grp in df.groupby(['fuzzer', 'subject']):
            color = color_map[key[0]]
            label = key[0]
            if label not in labels:
                labels.append(label)
            plt.subplot(3,5,sqs[key[1]], facecolor=(0.95, 0.95, 0.95))
            plt.plot(grp['time'], grp['cov'], label=label, color=color, linewidth=line_width)
            plt.title(target_name_map[key[1]], font_title)
            plt.ylim(bottom=ylims[key[1]][0], top=ylims[key[1]][1]) 
            plt.grid(linewidth=3, axis='y')

        # labels and other settings
        lines, labels = fig.axes[-1].get_legend_handles_labels()
        # change order
        tmp = lines[2]
        lines[2] = lines[4]
        lines[4] = tmp
        tmp = labels[2]
        labels[2] = labels[4]
        labels[4] = tmp
        labels = [fuzzer_name_map[x.lower()] for x in labels] # get the official name of the fuzzer
        fig.legend(lines, labels, loc="lower center", bbox_to_anchor=(0.86, 0.08), fontsize=font_size, shadow=True, framealpha=1, frameon=False)
        plt.subplots_adjust(left=None, bottom=None, right=None,
                            top=None, wspace=0.2, hspace=0.9)
        plt.tight_layout(rect=(0.05,0,0.95,1), w_pad=5, h_pad=40)
        pdf.savefig()
        plt.close()
    print("Finished: " + "./" + args.outfolder + '/fig-coverage.pdf')

    ################################# RQ3: get first crash time #################################
    time_dict = dict()
    for target in ['dnsmasq', 'tinydtls', 'live555', 'dcmtk']:
        target = target.lower()
        target_dict = dict()
        for fuzzer in fuzzers:
            target_dict[fuzzer] = list()
            for run in range(args.runs):
                outfolder = 'out-' + target + '-' + fuzzer
                os.system('tar -zxvf ' + './' + target + '/' + outfolder + '_' + str(run+1) + '.tar.gz > /dev/null 2>&1')
                if fuzzer == 'aflnwe':
                    fd = os.popen('./time-aflnwe.sh ' + outfolder)
                    output = fd.read()
                else:
                    fd = os.popen('./time.sh ' + outfolder)
                    output = fd.read()
                target_dict[fuzzer].append(eval(output[:-1]))
                os.system("rm -rf " + outfolder)
        time_dict[target] = target_dict

    time_average = dict()
    count_average = dict()
    for fuzzer in fuzzers:
        time_average[fuzzer] = 0
        count_average[fuzzer] = 0
    with open("./" + args.outfolder + '/table-crash-time.csv', 'w', newline='') as file:
        writer = csv.writer(file)
        writer.writerow([" "] + [fuzzer_name_map[x] for x in fuzzers])
        for target in time_dict.keys():
            item = [target_name_map[target]]
            for fuzzer in fuzzers:
                total = 0
                count = 0
                for x in range(args.runs):
                    if time_dict[target][fuzzer][x] < args.runtime:
                        total += time_dict[target][fuzzer][x]
                        count += 1
                if count != 0:
                    item.append(format(total/count, '.2f') + ' / ' + str(count))
                    time_average[fuzzer] += total/count
                    count_average[fuzzer] += count
                else:
                    item.append('N/A' + ' / ' + str(count))
                    time_average[fuzzer] += 0
                    count_average[fuzzer] += count
            writer.writerow(item)
        item = ['Average']
        for fuzzer in fuzzers:
            item.append(format(time_average[fuzzer] / 4, '.2f') + ' / ' + format(count_average[fuzzer] / 4, '.2f'))
        writer.writerow(item)

    print("Finished: " + "./" + args.outfolder + '/table-crash-time.csv')


    ################################## RQ4: process state space coverage ##################################
    # load basic info
    sv_dict = dict()
    sv_number = dict() # total number of each target
    for target in targets:
        sv_dict[target.lower()] = dict()
        sv_number[target.lower()] =  0
    with open('./sv_info.csv','r') as f:
        f_csv = csv.reader(f)
        for row in f_csv:
            sv_number[row[0]] += 1
            if row[1] != '':
                sv_dict[row[0]][row[1]] = eval(row[2])

    # process each target
    sv_result = dict()
    sv_uset = dict()
    for target in targets:
        sv_result[target.lower()] = dict()
        sv_uset[target.lower()] = dict()
    for target in targets:
        target_data = dict()
        target = target.lower()
        for fuzzer in fuzzers:
            target_data[fuzzer] = []
            for _ in range(args.runs):
                target_data[fuzzer].append(dict())
            for run in range(args.runs):
                filename = './' + target + '/' + 'out-' + target + '-' + fuzzer + '_sv_range_' + str(run+1) + '.json'
                with open(filename,'r') as f:
                    data = json.load(f)
                    target_data[fuzzer][run] = data
                    for item in data.keys():
                        if item != 'Total' and item not in sv_dict[target].keys():
                            print(target + '/' + item + ' not included in the sv dict.')
                        if item != 'Total':
                            if item not in sv_uset[target].keys():
                                sv_uset[target][item] = set(data[item])
                            else:
                                sv_uset[target][item].update(data[item])
        sv_result[target] = target_data


    average_sv = dict()
    for fuzzer in fuzzers:
        average = 0
        for target in targets:
            target = target.lower()
            total = sum(len(sv_uset[target][x]) for x in sv_uset[target].keys())
            average += sum(sv_result[target][fuzzer][x]['Total'] for x in range(args.runs)) /  args.runs / total
        average /= len(targets)
        average_sv[fuzzer] = format(average, '.2%')
    # plot hotmap
    data = []
    for target in targets:
        target = target.lower()
        item = []
        total = sum(len(sv_uset[target][x]) for x in sv_uset[target].keys())
        for fuzzer in fuzzers:
            item.append(sum(sv_result[target][fuzzer][x]['Total'] for x in range(args.runs)) /  args.runs / total)
        data.append(item)
    df = np.array(data)
    tag_x = [average_sv[x] + '\n' + fuzzer_name_map[x] for x in fuzzers]
    tag_y = targets
    fontsize = 9
    default_font = {'weight': 'bold', 'size': 10}

    with PdfPages("./" + args.outfolder + "/fig-sv-coverage.pdf") as pdf:
        fig, ax = plt.subplots(1, 1, figsize=(7, 5), dpi=300)
        plt.subplots_adjust(top=0.95, bottom=0.15, left=0.22, right=0.95, hspace=0, wspace=0)
        ax.set_xticks(np.arange(len(tag_x)))
        ax.set_yticks(np.arange(len(tag_y)))
        ax.set_xticklabels(tag_x, fontsize=fontsize)
        ax.set_yticklabels(tag_y, fontsize=fontsize)
        ax.set_xticks(np.arange(-.5, len(tag_x), 1), minor=True)
        ax.set_yticks(np.arange(-.5, len(tag_y), 1), minor=True)
        ax.grid(which="minor", color="w", linestyle='-', linewidth=3)
        plt.imshow(df, cmap='GnBu', origin='upper', aspect='auto')
        plt.rcParams['font.size'] = fontsize
        

        formatter = ticker.StrMethodFormatter('{x:.0%}')
        cbar = plt.colorbar(format=formatter)
        cbar.ax.tick_params(labelsize=fontsize)
        cbar.minorticks_on()

        plt.xlabel('Fuzzers', default_font)
        plt.ylabel('Target Service', default_font)
        ax.set_title("State Space Coverage", default_font)
        ax.grid(which='minor', color='w', linestyle='-', linewidth=1)
        pdf.savefig()
        
    print("Finished: " + "./" + args.outfolder + '/fig-sv-coverage.pdf')

