# mergerfs-tools

Optional tools to help manage data in a mergerfs pool.

## INSTALL

All of these suplimental tools are self contained Python3 apps. Make sure you have Python 3 installed and either run `make install` or copy the file to `/usr/local/bin` or wherever you keep your binarys and make it executable (chmod +x).

## TOOLS
### mergerfs.ctl

A wrapper around the mergerfs xattr interface.

```
$ mergerfs.ctl -h
usage: mergerfs.ctl [-h] [-m MOUNT] {add,remove,list,get,set,info} ...

positional arguments:
  {add,remove,list,get,set,info}

optional arguments:
  -h, --help            show this help message and exit
    -m MOUNT, --mount MOUNT
                            mergerfs mount to act on
$ mergerfs.ctl info
- mount: /storage
  version: 2.14.0
  pid: 1234
  srcmounts:
    - /mnt/drive0
    - /mnt/drive1
$ mergerfs.ctl -m /storage add path /mnt/drive2
$ mergerfs.ctl info
- mount: /storage
  version: 2.14.0
  pid: 1234
  srcmounts:
    - /mnt/drive0
    - /mnt/drive1
    - /mnt/drive2
```

### mergerfs.fsck

Audits permissions and ownership of files and directories in a mergerfs mount and allows for manual and automatic fixing of them.

It's possible that files or directories can be duplicated across multiple drives and that their metadata become out of sync. Permissions, ownership, etc. This can cause some strange behavior depending on the mergerfs policies used. This tool helps find and fix those inconsistancies.

```
$ mergerfs.fsck -h
usage: mergerfs.fsck [-h] [-v] [-s] [-f {manual,newest,nonroot}] dir

audit a mergerfs mount for inconsistencies

positional arguments:
  dir                   starting directory

  optional arguments:
    -h, --help            show this help message and exit
    -v, --verbose         print details of audit item
    -s, --size            only consider if the size is the same
    -f {manual,newest,nonroot}, --fix {manual,newest,nonroot}
                          fix policy
$ mergerfs.fsck -v -f manual /path/to/dir
```

### mergerfs.dup

Duplicates files & directories across branches in a pool. The file selected for duplication is picked by the `dup` option. Files will be copied to drives with the most free space. Deleted from others if `prune` is enabled.

See usage for more. Run as `root`. Requires `rsync` to be installed.

```
usage: mergerfs.dup [<options>] <dir>

Duplicate files & directories across multiple drives in a pool.
Will print out commands for inspection and out of band use.

positional arguments:
  dir                    starting directory

optional arguments:
  -c, --count=           Number of copies to create. (default: 2)
  -d, --dup=             Which file (if more than one exists) to choose to
                         duplicate. Each one falls back to `mergerfs` if
                         all files have the same value. (default: newest)
                         * newest   : file with largest mtime
                         * oldest   : file with smallest mtime
                         * smallest : file with smallest size
                         * largest  : file with largest size
                         * mergerfs : file chosen by mergerfs' getattr
  -p, --prune            Remove files above `count`. Without this enabled
                         it will update all existing files.
  -e, --execute          Execute `rsync` and `rm` commands. Not just
                         print them.
  -I, --include=         fnmatch compatible filter to include files.
                         Can be used multiple times.
  -E, --exclude=         fnmatch compatible filter to exclude files.
                         Can be used multiple times.
```


### mergerfs.dedup

Finds and removes duplicate files across mergerfs pool's branches. Use the
`ignore`, `dedup`, and `strict` options to target specific use cases.


```
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
                         * same-size      : have the same size
                         * different-size : have different sizes
                         * same-time      : have the same mtime
                         * different-time : have different mtimes
                         * same-hash      : have the same md5sum
                         * different-hash : have different md5sums
  -d, --dedup=           What file to *keep* (default: newest)
                         * manual        : ask user
                         * oldest        : file with smallest mtime
                         * newest        : file with largest mtime
                         * largest       : file with largest size
                         * smallest      : file with smallest size
                         * mostfreespace : file on drive with most free space
  -s, --strict           Skip dedup if all files have same value.
                         Only applies to oldest, newest, largest, smallest.
  -e, --execute          Will not perform file removal without this.
  -I, --include=         fnmatch compatible filter to include files.
                         Can be used multiple times.
  -E, --exclude=         fnmatch compatible filter to exclude files.
                         Can be used multiple times.

# mergerfs.dedup /path/to/dir
# Total savings: 10.0GB

# mergerfs.dedup -e -d newest /path/to/dir
mergerfs.dedup -v -d newest /media/tmp/test
rm -vf /mnt/drive0/test/foo
rm -vf /mnt/drive1/test/foo
rm -vf /mnt/drive2/test/foo
rm -vf /mnt/drive3/test/foo
# Total savings: 10.0B
```


### mergerfs.balance

Will move files from the most filled drive (percentage wise) to the least filled drive. Will do so till the most and least filled drives come within a user defined percentage range (defaults to 2%).

Run as `root`. Requires `rsync` to be installed.

```
usage: mergerfs.balance [-h] [-p PERCENTAGE] [-i INCLUDE] [-e EXCLUDE]
                        [-I INCLUDEPATH] [-E EXCLUDEPATH] [-s EXCLUDELT]
                        [-S EXCLUDEGT]
                        dir

balance files on a mergerfs mount based on percentage drive filled

positional arguments:
  dir                   starting directory

optional arguments:
  -h, --help            show this help message and exit
  -p PERCENTAGE         percentage range of freespace (default 2.0)
  -i INCLUDE, --include INCLUDE
                        fnmatch compatible file filter (can use multiple
                        times)
  -e EXCLUDE, --exclude EXCLUDE
                        fnmatch compatible file filter (can use multiple
                        times)
  -I INCLUDEPATH, --include-path INCLUDEPATH
                        fnmatch compatible path filter (can use multiple
                        times)
  -E EXCLUDEPATH, --exclude-path EXCLUDEPATH
                        fnmatch compatible path filter (can use multiple
                        times)
  -s EXCLUDELT          exclude files smaller than <int>[KMGT] bytes
  -S EXCLUDEGT          exclude files larger than <int>[KMGT] bytes

# mergerfs.balance /media
from: /mnt/drive1/foo/bar
to:   /mnt/drive2/foo/bar
rsync ...
```


### mergerfs.consolidate

Consolidate **files** in a **single** mergerfs directory onto a **single** drive, recursively. This does **NOT** move all files at and below that directory to 1 drive. If you want to move data between drives simply use normal rsync or similar. This tool is only useful in niche usecases where the person wants to colocate files of their TV, music, etc. files onto a single drive *after the fact.* If you really wanted that you should probably use path preservation. For most people there is only downsides to using path preservation or colocating files.

Run as `root`. Requires `rsync` to be installed.

```
usage: mergerfs.consolidate [<options>] <dir>

positional arguments:
  dir                    starting directory

optional arguments:
  -m, --max-files=       Skip directories with more than N files.
                         (default: 256)
  -M, --max-size=        Skip directories with files adding up to more
                         than N. (default: 16G)
  -I, --include-path=    fnmatch compatible path include filter.
                         Can be used multiple times.
  -E, --exclude-path=    fnmatch compatible path exclude filter.
                         Can be used multiple times.
  -e, --execute          Execute `rsync` commands as well as print them.
  -h, --help             Print this help.
```


### mergerfs.mktrash

Will create [FreeDesktop.org Trash specification](https://specifications.freedesktop.org/trash-spec/trashspec-1.0.html) compatible directories on a mergerfs mount. Helps minimize issues with apps which `rename` into the trash directory. This shouldn't be necessary if you're not using a path perservation policy.

```
$ mergerfs.mktrash /mountpoint
```

## SUPPORT

#### Contact / Issue submission
* github.com: https://github.com/trapexit/mergerfs-tools/issues
* email: trapexit@spawn.link
* twitter: https://twitter.com/_trapexit

#### Support development

This software is free to use and released under a very liberal license. That said if you like this software and would like to support its development donations are welcome.

* Bitcoin (BTC): 12CdMhEPQVmjz3SSynkAEuD5q9JmhTDCZA
* Bitcoin Cash (BCH): 1AjPqZZhu7GVEs6JFPjHmtsvmDL4euzMzp
* Ethereum (ETH): 0x09A166B11fCC127324C7fc5f1B572255b3046E94
* Litecoin (LTC): LXAsq6yc6zYU3EbcqyWtHBrH1Ypx4GjUjm
* Ripple (XRP): rNACR2hqGjpbHuCKwmJ4pDpd2zRfuRATcE
* PayPal: trapexit@spawn.link
* Patreon: https://www.patreon.com/trapexit

## LINKS

* http://github.com/trapexit/mergerfs
* http://github.com/trapexit/mergerfs-tools
* http://github.com/trapexit/scorch
* http://github.com/trapexit/backup-and-recovery-howtos
