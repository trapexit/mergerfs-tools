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
import ctypes
import errno
import fnmatch
import hashlib
import io
import os
import random
import shlex
import sys


_libc = ctypes.CDLL("libc.so.6",use_errno=True)
_lgetxattr = _libc.lgetxattr
_lgetxattr.argtypes = [ctypes.c_char_p,ctypes.c_char_p,ctypes.c_void_p,ctypes.c_size_t]
def lgetxattr(path,name):
    if type(path) == str:
        path = path.encode(errors='backslashreplace')
    if type(name) == str:
        name = name.encode(errors='backslashreplace')
    length = 64
    while True:
        buf = ctypes.create_string_buffer(length)
        res = _lgetxattr(path,name,buf,ctypes.c_size_t(length))
        if res >= 0:
            return buf.raw[0:res]
        else:
            err = ctypes.get_errno()
            if err == errno.ERANGE:
                length *= 2
            elif err == errno.ENODATA:
                return None
            else:
                raise IOError(err,os.strerror(err),path)


def ismergerfs(path):
    try:
        lgetxattr(path,b'user.mergerfs.fullpath')
        return True
    except IOError as e:
        return False


def hash_file(filepath, hasher=None, blocksize=65536):
    if not hasher:
        hasher = hashlib.md5()

    with open(filepath,'rb') as afile:
        buf = afile.read(blocksize)
        while buf:
            hasher.update(buf)
            buf = afile.read(blocksize)

    return hasher.hexdigest()


def short_hash_file(filepath, hasher=None, blocksize=65536, blocks=16):
    if not hasher:
        hasher = hashlib.md5()

    with open(filepath,'rb') as f:
        size = os.fstat(f.fileno()).st_size
        if size <= blocksize:
            size = 1
            blocks = 1

        random.seed(size,version=2)
        for _ in range(blocks):
            offset = random.randrange(size)
            f.seek(offset)
            buf = f.read(blocksize)
            if buf:
                hasher.update(buf)
            else:
                break

    return hasher.hexdigest()


def sizeof_fmt(num):
    for unit in ['','K','M','G','T','P','E','Z']:
        if abs(num) < 1024.0:
            return "%3.1f%sB" % (num,unit)
        num /= 1024.0
    return "%.1f%sB" % (num,'Y')


def stat_files(paths):
    rv = []
    for path in paths:
        try:
            st = os.stat(path)
            rv.append((path,st))
        except:
            pass

    return rv


def remove(files,execute,verbose):
    for (path,stat) in files:
        try:
            print('rm -vf',shlex.quote(path))
            if execute:
                os.remove(path)
        except Exception as e:
            print("%s" % e)


def print_stats(stats):
    for i in range(0,len(stats)):
        print("#  %i: %s" % (i+1,stats[i][0]))
        data = ("#   - uid: {0:5}; gid: {1:5}; mode: {2:6o}; "
                "size: {3}; mtime: {4}").format(
            stats[i][1].st_uid,
            stats[i][1].st_gid,
            stats[i][1].st_mode,
            sizeof_fmt(stats[i][1].st_size),
            stats[i][1].st_mtime)
        print(data)


def total_size(stats):
    total = 0
    for (name,stat) in stats:
        total = total + stat.st_size
    return total


def manual_dedup(fullpath,stats):
    done = False
    while not done:
        value = input("# Which to keep? ('s' to skip):")

        if value.lower() == 's':
            stats.clear()
            done = True
            continue

        try:
            value = int(value) - 1
            if value < 0 or value >= len(stats):
                raise ValueError
            stats.remove(stats[value])
            done = True
        except NameError:
            print("Input error: enter a value [1-{0}] or skip by entering 's'".format(len(stats)))
        except ValueError:
            print("Input error: enter a value [1-{0}] or skip by entering 's'".format(len(stats)))


def mtime_all(stats):
    mtime = stats[0][1].st_mtime
    return all(x[1].st_mtime == mtime for x in stats)


def mtime_any(mtime,stats):
    return any([st.st_mtime == mtime for (path,st) in stats])


def size_all(stats):
    size = stats[0][1].st_size
    return all(x[1].st_size == size for x in stats)


def size_any(size,stats):
    return any([st.st_size == size for (path,st) in stats])


def md5sums_all(stats):
    if size_all(stats):
        hashval = hash_file(stats[0][0])
        return all(hash_file(path) == hashval for (path,st) in stats[1:])
    return False


def short_md5sums_all(stats):
    if size_all(stats):
        hashval = short_hash_file(stats[0][0])
        return all(short_hash_file(path) == hashval for (path,st) in stats[1:])
    return False


def oldest_dedup(fullpath,stats):
    if size_all(stats) and mtime_all(stats):
        drive_with_most_space_dedup(fullpath,stats)
        return

    stats.sort(key=lambda st: st[1].st_mtime)
    oldest = stats[0]
    stats.remove(oldest)


def strict_oldest_dedup(fullpath,stats):
    stats.sort(key=lambda st: st[1].st_mtime,reverse=False)

    oldest = stats[0]
    stats.remove(oldest)
    if mtime_any(oldest[1].st_mtime,stats):
        stats.clear()


def newest_dedup(fullpath,stats):
    if size_all(stats) and mtime_all(stats):
        drive_with_most_space_dedup(fullpath,stats)
        return

    stats.sort(key=lambda st: st[1].st_mtime,reverse=True)
    newest = stats[0]
    stats.remove(newest)


def strict_newest_dedup(fullpath,stats):
    stats.sort(key=lambda st: st[1].st_mtime,reverse=True)

    newest = stats[0]
    stats.remove(newest)
    if mtime_any(newest[1].st_mtime,stats):
        stats.clear()


def largest_dedup(fullpath,stats):
    if size_all(stats) and mtime_all(stats):
        drive_with_most_space_dedup(fullpath,stats)
        return

    stats.sort(key=lambda st: st[1].st_size,reverse=True)
    largest = stats[0]
    stats.remove(largest)


def strict_largest_dedup(fullpath,stats):
    stats.sort(key=lambda st: st[1].st_size,reverse=True)

    largest = stats[0]
    stats.remove(largest)
    if size_any(largest[1].st_size,stats):
        stats.clear()


def smallest_dedup(fullpath,stats):
    if size_all(stats) and mtime_all(stats):
        drive_with_most_space_dedup(fullpath,stats)
        return

    stats.sort(key=lambda st: st[1].st_size)
    smallest = stats[0]
    stats.remove(smallest)


def strict_smallest_dedup(fullpath,stats):
    stats.sort(key=lambda st: st[1].st_size,reverse=False)

    smallest = stats[0]
    stats.remove(smallest)
    if size_any(smallest[1].st_size,stats):
        stats.clear()


def calc_space_free(stat):
    st = os.statvfs(stat[0])
    return st.f_frsize * st.f_bfree


def drive_with_most_space_dedup(fullpath,stats):
    stats.sort(key=calc_space_free,reverse=True)
    largest = stats[0]
    stats.remove(largest)


def mergerfs_getattr_dedup(origpath,stats):
    fullpath = getxattr(origpath,b'user.mergerfs.fullpath')
    for (path,stat) in stats:
        if path != fullpath:
            continue
        stats.remove((path,stat))
        break


def get_dedupfun(name,strict):
    if strict:
        name = 'strict-' + name
    funs = {
        'manual': manual_dedup,
        'strict-manual': manual_dedup,
        'mostfreespace': drive_with_most_space_dedup,
        'strict-mostfreespace': drive_with_most_space_dedup,
        'newest': newest_dedup,
        'strict-newest': strict_newest_dedup,
        'oldest': oldest_dedup,
        'strict-oldest': strict_oldest_dedup,
        'largest': largest_dedup,
        'strict-largest': strict_largest_dedup,
        'smallest': smallest_dedup,
        'strict-smallest': strict_smallest_dedup,
        'mergerfs': mergerfs_getattr_dedup,
        'strict-mergerfs': mergerfs_getattr_dedup
    }
    return funs[name]


def get_ignorefun(name):
    funs = {
        None: lambda x: None,
        'same-time': mtime_all,
        'diff-time': lambda x: not mtime_all(x),
        'same-size': size_all,
        'diff-size': lambda x: not size_all(x),
        'same-hash': md5sums_all,
        'diff-hash': lambda x: not md5sums_all(x),
        'same-short-hash': short_md5sums_all,
        'diff-short-hash': lambda x: not short_md5sums_all(x)
    }

    return funs[name]


def getxattr(path,key):
    try:
        attr = lgetxattr(path,key)
        if attr:
            return attr.decode('utf-8')
        return ''
    except IOError as e:
        if e.errno == errno.ENODATA:
            return ''
        raise
    except UnicodeDecodeError as e:
        print(e)
        print(attr)
    return ''


def match(filename,matches):
    for match in matches:
        if fnmatch.fnmatch(filename,match):
            return True
    return False


def dedup(fullpath,verbose,ignorefun,execute,dedupfun):
    paths = getxattr(fullpath,b'user.mergerfs.allpaths').split('\0')
    if len(paths) <= 1:
        return 0

    stats = stat_files(paths)

    if ignorefun(stats):
        if verbose >= 2:
            print('# ignored:',fullpath)
        return 0

    if (dedupfun == manual_dedup):
        print('#',fullpath)
        print_stats(stats)

    try:
        dedupfun(fullpath,stats)
        if not stats:
            if verbose >= 2:
                print('# skipped:',fullpath)
            return 0

        if (dedupfun != manual_dedup):
            if verbose >= 2:
                print('#',fullpath)
            if verbose >= 3:
                print_stats(stats)

        for (path,stat) in stats:
            try:
                if verbose:
                    print('rm -vf',shlex.quote(path))
                if execute:
                    os.remove(path)
            except Exception as e:
                print('#',e)

        return total_size(stats)

    except Exception as e:
        print(e)

    return 0


def print_help():
    help = \
'''
usage: mergerfs.dedup [<options>] <dir>

Remove duplicate files across branches of a mergerfs pool. Provides
multiple algos for determining which file to keep and what to skip.

positional arguments:
  dir                    Starting directory

optional arguments:
  -v, --verbose          Once to print `rm` commands
                         Twice for status info
                         Three for file info
  -i, --ignore=          Ignore files if... (default: none)
                         * same-size       : have the same size
                         * diff-size       : have different sizes
                         * same-time       : have the same mtime
                         * diff-time       : have different mtimes
                         * same-hash       : have the same md5sum
                         * diff-hash       : have different md5sums
                         * same-short-hash : have the same short md5sums
                         * diff-short-hash : have different short md5sums
                         'hash' is expensive. 'short-hash' far less
                         expensive, not as safe, but pretty good.
  -d, --dedup=           What file to *keep* (default: mergerfs)
                         * manual        : ask user
                         * oldest        : file with smallest mtime
                         * newest        : file with largest mtime
                         * largest       : file with largest size
                         * smallest      : file with smallest size
                         * mostfreespace : file on drive with most free space
                         * mergerfs      : file selected by the mergerfs
                                           getattr policy
  -s, --strict           Skip dedup if all files have same (mtime,size) value.
                         Only applies to oldest, newest, largest, smallest.
  -e, --execute          Will not perform file removal without this.
  -I, --include=         fnmatch compatible filter to include files.
                         Can be used multiple times.
  -E, --exclude=         fnmatch compatible filter to exclude files.
                         Can be used multiple times.

'''
    print(help)


def buildargparser():
    desc = 'dedup files across branches in a mergerfs pool'
    usage = 'mergerfs.dedup [<options>] <dir>'
    parser = argparse.ArgumentParser(add_help=False)

    parser.add_argument('dir',
                        type=str,
                        nargs='?',
                        default=None,
                        help='starting directory')
    parser.add_argument('-v','--verbose',
                        action='count',
                        default=0)
    parser.add_argument('-i','--ignore',
                        choices=['same-size','diff-size',
                                 'same-time','diff-time',
                                 'same-hash','diff-hash',
                                 'same-short-hash',
                                 'diff-short-hash'])
    parser.add_argument('-d','--dedup',
                        choices=['manual',
                                 'oldest','newest',
                                 'smallest','largest',
                                 'mostfreespace',
                                 'mergerfs'],
                        default='mergerfs')
    parser.add_argument('-s','--strict',
                        action='store_true')
    parser.add_argument('-e','--execute',
                        action='store_true')
    parser.add_argument('-I','--include',
                        type=str,
                        action='append',
                        default=[])
    parser.add_argument('-E','--exclude',
                        type=str,
                        action='append',
                        default=[])
    parser.add_argument('-h','--help',
                        action='store_true')

    return parser


def main():
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer,
                                  encoding='utf8',
                                  errors='backslashreplace',
                                  line_buffering=True)
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer,
                                  encoding='utf8',
                                  errors='backslashreplace',
                                  line_buffering=True)

    parser = buildargparser()
    args   = parser.parse_args()

    if args.help or not args.dir:
        print_help()
        sys.exit(0)

    args.dir = os.path.realpath(args.dir)
    if not ismergerfs(args.dir):
        print("%s is not a mergerfs directory" % args.dir)
        sys.exit(1)

    dedupfun  = get_dedupfun(args.dedup,args.strict)
    ignorefun = get_ignorefun(args.ignore)
    verbose   = args.verbose
    execute   = args.execute
    includes  = ['*'] if not args.include else args.include
    excludes  = args.exclude

    total_size = 0
    try:
        for (dirname,dirnames,filenames) in os.walk(args.dir):
            for filename in filenames:
                if match(filename,excludes):
                    continue
                if not match(filename,includes):
                    continue
                fullpath    = os.path.join(dirname,filename)
                total_size += dedup(fullpath,verbose,ignorefun,execute,dedupfun)
    except KeyboardInterrupt:
        print("# exiting: CTRL-C pressed")
    except IOError as e:
        if e.errno == errno.EPIPE:
            pass
        else:
            raise

    print('# Total savings:',sizeof_fmt(total_size))

    sys.exit(0)


if __name__ == "__main__":
    main()
