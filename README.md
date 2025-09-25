This branch is intended to allow the client to run under Alpine, so it implements compilation in an Alpine environment. At present, only the `taos`  command has been verified to work; other features have not been tested.

<https://github.com/wendaoji/tdengine-tsdb-oss-client>

# build

```bash
docker buildx build --platform=linux/amd64,linux/arm64 -t wendaoji/tdengine-tsdb-oss-client --build-arg VERSION=3.3.7.5 .
```

# build for alpine(Deprecated)

```bash
docker build -t wendaoji/tdengine-tsdb-oss-client:3.3.7.5-alpine -f Dockerfile.alpine .
# or
VERNUMBER=3.3.7.5
TAOSADAPTER_GIT_TAG_NAME=ver-3.3.7.5
NPROC=$(nproc)
# --platform linux/amd64 linux/arm64
docker build -t wendaoji/tdengine-tsdb-oss-client:3.3.7.5-alpine --progress=plain --build-arg NPROC=NPROC --build-arg VERNUMBER=${VERNUMBER} --build-arg TAOSADAPTER_GIT_TAG_NAME=${TAOSADAPTER_GIT_TAG_NAME} --platform linux/arm64 .
```


# run

```bash
# use taos
docker run --rm -i wendaoji/tdengine-tsdb-oss-client:3.3.7.5 taos -h xxxxxx -u root -P 6030 -ptaosdata

# By default, logs are written to `/var/log/taos`. If the process lacks write permission there, you can either:
# 1. Set a different directory in `taos.cfg` (`logDir ...`), or
# 2. Run with `-o /dev/null` to discard logs.
docker run --rm -it wendaoji/tdengine-tsdb-oss-client:3.3.7.5 sh
echo "logDir /taos/logs" >> /etc/taos/taos.cfg
taos -h xxxxxx -u root -P 6030 -ptaosdata
```


# run jdbc for native

1. It is recommended not to set the environment variable `TD_LIBRARY_PATH`. When `TD_LIBRARY_PATH` is specified and loading fails, the concrete error message is suppressed. Instead, mount the shared libraries directly into one of the default JVM library paths, e.g. `/usr/java/packages/lib:/usr/lib64:/lib64:/lib:/usr/lib`.

Note:
- `taos-jdbcdriver-3.3.3.jar` does not contain this parameter.
- `taos-jdbcdriver-3.6.3.jar` does contain it.

The static block in `com.taosdata.jdbc.TSDBJNIConnector` handles exceptions improperly when `TD_LIBRARY_PATH` is set, thereby masking the real error.

2. When running in native mode, logs are written to `/var/log/taos` by default. If the log shows a permission error, it is usually because the process cannot write to `/var/log/taos`(the JDBC driver does not report the exact permission problem). You can change the log directory by setting `logDir` in `taos.cfg`, which is located in `/etc/taos` by default.

3. For other settings, refer to [run taos](#-run-taos).

4. jdbc url: `jdbc:TAOS://tsdb:6030/test`


# faq

## in macos m1 use rosetta run taos native for amd64.

```bash
# rosetta error: Unimplemented syscall number 156
$ /usr/local/taos/bin/taos -h xxxx -u root -P 6030 -ptaosdata -s "show databases"
rosetta error: Unimplemented syscall number 156
 Trace/breakpoint trap (core dumped)

# search syscall
$ apt install -y auditd
$ ausyscall 156
/usr/local/taos/cfg/taos.cfg
_sysctl

# search tdegine source
$ cd TDengine
$ grep -R -E "_sysctl" .
grep: ./deps/arm/dm_static/libdmodule.a: binary file matches
./source/os/src/osSysinfo.c:  struct __sysctl_args args;
./source/os/src/osSysinfo.c:  (void)memset(&args, 0, sizeof(struct __sysctl_args));
./source/os/src/osSysinfo.c:  if (syscall(SYS__sysctl, &args) == -1) {
./source/os/src/osSysinfo.c:    // printf("_sysctl(kern_core_uses_pid) set fail: %s", strerror(ERRNO));
./source/os/src/osSysinfo.c:  (void)memset(&args, 0, sizeof(struct __sysctl_args));
./source/os/src/osSysinfo.c:  if (syscall(SYS__sysctl, &args) == -1) {
./source/os/src/osSysinfo.c:    // printf("_sysctl(kern_core_uses_pid) get fail: %s", strerror(ERRNO));
./test/new_test_framework/taostest/stability/agent_dockerfile/telegraf/telegraf.conf1:# [[inputs.linux_sysctl_fs]]

$ more source/os/src/osSysinfo.c
void taosSetCoreDump(bool enable) {
  if (!enable) return;
  ...
  #ifndef _TD_ARM_
    // 2. set the path for saving core file
    struct __sysctl_args args;
$ more source/common/src/tglobal.c
  TAOS_CHECK_GET_CFG_ITEM(pCfg, pItem, "enableCoreFile");
  tsEnableCoreFile = pItem->bval;
  taosSetCoreDump(tsEnableCoreFile);

# see https://docs.taosdata.com/reference/components/taosc/#enablecorefile
$ echo "enableCoreFile 0" > /usr/local/taos/cfg/taos.cfg
# or exec sql  SET MAX_BINARY_DISPLAY_WIDTH 120;
# run again. success!
$ /usr/local/taos/bin/taos -h xxxx -u root -P 6030 -ptaosdata -s "show databases"

```

The _sysctlsystem call - a deprecated Linux kernel interface superseded by procfs/sysfs - encounters compatibility issues under macOS Rosetta 2's x86_64 emulation due to incomplete implementation of certain legacy system calls.
