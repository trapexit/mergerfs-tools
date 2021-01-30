#!/usr/bin/env python3

# Copyright (c) 2016, Antonio SJ Musumeci <trapexit@spawn.link>

# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.

# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

import argparse
import os
import sys


def find_mergerfs():
    rv = []
    with open('/proc/self/mountinfo','r') as f:
        for line in f:
            values = line.split()
            mountroot, mountpoint = values[3:5]
            separator = values.index('-', 6)
            fstype = values[separator + 1]
            if fstype == 'fuse.mergerfs' and mountroot == '/':
                rv.append(mountpoint.encode().decode('unicode_escape'))
    return rv


def ask_about_path(paths):
    prompt = 'Available mergerfs mounts:\n'
    for i in range(0,len(paths)):
        prompt += ' {0}: {1}\n'.format(i,paths[i])
    prompt += 'Choose which mount to act on: '
    path = input(prompt)
    return paths[int(path)]


def device2mount(device):
    with open('/proc/mounts','r') as f:
        for line in f:
            columns = line.split()
            if columns[0] == device:
                return columns[1]
    with open('/etc/fstab','r') as f:
        for line in f:
            columns = line.split()
            try:
                if columns[0] == device:
                    return columns[1]
                realpath = os.path.realpath(columns[0])
                if realpath == device:
                    return columns[1]
            except:
                pass
    return None


def control_file(path):
    return os.path.join(path,'.mergerfs')


def add_srcmount(ctrlfile,srcmount):
    key   = b'user.mergerfs.srcmounts'
    value = b'+' + srcmount.encode()
    try:
        os.setxattr(ctrlfile,key,value)
    except Exception as e:
        print(e)


def remove_srcmount(ctrlfile,srcmount):
    key   = b'user.mergerfs.srcmounts'
    value = b'-' + srcmount.encode()
    try:
        os.setxattr(ctrlfile,key,value)
    except Exception as e:
        print(e)


def normalize_key(key):
    if type(key) == bytes:
        if key.startswith(b'user.mergerfs.'):
            return key
        return b'user.mergerfs.' + key
    elif type(key) == str:
        if key.startswith('user.mergerfs.'):
            return key
        return 'user.mergerfs.' + key


def print_mergerfs_info(fspaths):
    for fspath in fspaths:
        ctrlfile  = control_file(fspath)
        version   = os.getxattr(ctrlfile,'user.mergerfs.version')
        pid       = os.getxattr(ctrlfile,'user.mergerfs.pid')
        srcmounts = os.getxattr(ctrlfile,'user.mergerfs.srcmounts')
        output = ('- mount: {0}\n'
                  '  version: {1}\n'
                  '  pid: {2}\n'
                  '  srcmounts:\n'
                  '    - ').format(fspath,
                                   version.decode(),
                                   pid.decode())
        srcmounts = srcmounts.decode().split(':')
        output += '\n    - '.join(srcmounts)
        print(output)


def build_arg_parser():
    desc = 'a tool for runtime manipulation of mergerfs'
    parser = argparse.ArgumentParser(description=desc)

    subparsers = parser.add_subparsers(dest='command')

    parser.add_argument('-m','--mount',
                        type=str,
                        help='mergerfs mount to act on')

    addopt = subparsers.add_parser('add')
    addopt.add_argument('type',choices=['path','device'])
    addopt.add_argument('path',type=str)
    addopt.set_defaults(func=cmd_add)

    removeopt = subparsers.add_parser('remove')
    removeopt.add_argument('type',choices=['path','device'])
    removeopt.add_argument('path',type=str)
    removeopt.set_defaults(func=cmd_remove)

    listopt = subparsers.add_parser('list')
    listopt.add_argument('type',choices=['options','values'])
    listopt.set_defaults(func=cmd_list)

    getopt = subparsers.add_parser('get')
    getopt.add_argument('option',type=str,nargs='+')
    getopt.set_defaults(func=cmd_get)

    setopt = subparsers.add_parser('set')
    setopt.add_argument('option',type=str)
    setopt.add_argument('value',type=str)
    setopt.set_defaults(func=cmd_set)

    infoopt = subparsers.add_parser('info')
    infoopt.set_defaults(func=cmd_info)

    return parser


def cmd_add(fspaths,args):
    if args.type == 'device':
        return cmd_add_device(fspaths,args)
    elif args.type == 'path':
        return cmd_add_path(fspaths,args)

def cmd_add_device(fspaths,args):
    for fspath in fspaths:
        ctrlfile = control_file(fspath)
        mount = device2mount(args.path)
        if mount:
            add_srcmount(ctrlfile,mount)
        else:
            print('{0} not found'.format(args.path))

def cmd_add_path(fspaths,args):
    for fspath in fspaths:
        ctrlfile = control_file(fspath)
        add_srcmount(ctrlfile,args.path)


def cmd_remove(fspaths,args):
    if args.type == 'device':
        return cmd_remove_device(fspaths,args)
    elif args.type == 'path':
        return cmd_remove_path(fspaths,args)

def cmd_remove_device(fspaths,args):
    for fspath in fspaths:
        ctrlfile = control_file(fspath)
        mount = device2mount(args.path)
        if mount:
            remove_srcmount(ctrlfile,mount)
        else:
            print('{0} not found'.format(args.path.decode()))

def cmd_remove_path(fspaths,args):
    for fspath in fspaths:
        ctrlfile = control_file(fspath)
        remove_srcmount(ctrlfile,args.path)


def cmd_list(fspaths,args):
    if args.type == 'values':
        return cmd_list_values(fspaths,args)
    if args.type == 'options':
        return cmd_list_options(fspaths,args)

def cmd_list_options(fspaths,args):
    for fspath in fspaths:
        ctrlfile = control_file(fspath)
        keys = os.listxattr(ctrlfile)
        output = ('- mount: {0}\n'
                  '  options:\n').format(fspath)
        for key in keys:
            output += '    - {0}\n'.format(key)
        print(output,end='')

def cmd_list_values(fspaths,args):
    for fspath in fspaths:
        ctrlfile = control_file(fspath)
        keys = os.listxattr(ctrlfile)
        output = ('- mount: {0}\n'
                  '  options:\n').format(fspath)
        for key in keys:
            value = os.getxattr(ctrlfile,key)
            output += '    {0}: {1}\n'.format(key,value.decode())
        print(output,end='')


def cmd_get(fspaths,args):
    for fspath in fspaths:
        ctrlfile = control_file(fspath)
        print('- mount: {0}'.format(fspath))
        for key in args.option:
            key   = normalize_key(key)
            value = os.getxattr(ctrlfile,key).decode()
            print('    {0}: {1}'.format(key,value))


def cmd_set(fspaths,args):
    for fspath in fspaths:
        ctrlfile = control_file(fspath)
        key = normalize_key(args.option)
        value = args.value.encode()
        try:
            os.setxattr(ctrlfile,key,value)
        except Exception as e:
            print(e)


def cmd_info(fspaths,args):
    print_mergerfs_info(fspaths)


def print_and_exit(string,rv):
    print(string)
    sys.exit(rv)


def main():
    parser = build_arg_parser()
    args   = parser.parse_args()

    fspaths = find_mergerfs()
    if args.mount and args.mount in fspaths:
        fspaths = [args.mount]
    elif not args.mount and not fspaths:
        print_and_exit('no mergerfs mounts found',1)
    elif args.mount and args.mount not in fspaths:
        print_and_exit('{0} is not a mergerfs mount'.format(args.mount),1)

    if hasattr(args, 'func'):
        args.func(fspaths,args)
    else:
        parser.print_help()

    sys.exit(0)


if __name__ == "__main__":
    main()
