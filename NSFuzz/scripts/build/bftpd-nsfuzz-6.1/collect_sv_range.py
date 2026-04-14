import os
import json

sv_list_file = '/tmp/sv_list_temp'
sv_range_file = '/tmp/sv_range.txt'
sv_range_json = '/tmp/sv_range.json'

def main():
    if not os.path.exists(sv_list_file) or not os.path.exists(sv_range_file):
        raise Exception("Cannot find the sv files!")
    sv_list = []
    sv_range_dict = {}
    total_val = 0
    with open(sv_list_file, 'r') as f:
        lines = f.readlines()
        for line in lines:
            sv_list.append(line.strip())
    with open(sv_range_file, 'r') as f:
        lines = f.readlines()
        for line in lines:
            num, val = line.split()
            sv = sv_list[int(num)]
            if sv not in sv_range_dict.keys():
                sv_range_dict[sv] = []
            sv_range_dict[sv].append(int(val))
            total_val += 1
    sv_range_dict['Total'] = total_val
    with open(sv_range_json, 'w') as f:
        f.write(json.dumps(sv_range_dict))

if __name__ == '__main__':
    main()
