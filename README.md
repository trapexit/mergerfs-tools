# mergerfs-tools
Optional tools to help manage data in a mergerfs pool

## mergerfs.ctl

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

## mergerfs.fsck

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


## mergerfs.dedup

Finds and deduplicate files.

```
$ mergerfs.dedup -h
usage: mergerfs.dedup [-h] [-v] [-i] [-d {manual,newest,largest}] dir

dedup files on a mergerfs mount

positional arguments:
  dir                   starting directory

  optional arguments:
    -h, --help            show this help message and exit
    -v, --verbose         print details of files
    -i, --ignoresize      ignore files of the same size
    -d {manual,newest,largest}, --dedup {manual,newest,largest}
                          dedup policy
$ mergerfs.dedup -v -d manual -v /path/to/dir
```


## mergerfs.rebalance

**TO BE CREATED**

Simplifies rebalancing of files across drives.


## mergerfs.mktrash

Will create [FreeDesktop.org Trash specification](https://specifications.freedesktop.org/trash-spec/trashspec-1.0.html) compatible directories on a mergerfs mount. Helps minimize issues with apps which `rename` into the trash directory.

```
$ mergerfs.mktrash /mountpoint
```
