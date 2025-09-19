This branch is intended to allow the client to run under Alpine, so it implements compilation in an Alpine environment. At present, only the `taos`  command has been verified to work; other features have not been tested.

# build

```bash
docker build -t tdengine/tdengine-tsdb-oss-client:3.3.7.5-alpine .
# or
VERNUMBER=3.3.7.5
TAOSADAPTER_GIT_TAG_NAME=ver-3.3.7.5
NPROC=$(nproc)
docker build -t tdengine/tdengine-tsdb-oss-client:3.3.7.5-alpine --progress=plain --build-arg NPROC=NPROC --build-arg VERNUMBER=${VERNUMBER} --build-arg TAOSADAPTER_GIT_TAG_NAME=${TAOSADAPTER_GIT_TAG_NAME} .
```


# run

```bash
# use taos
docker run --rm tdengine/tdengine-tsdb-oss-client:3.3.7.5-alpine taos -h xxxxxx -u root -P 6030 -ptaosdata

# By default, logs are written to `/var/log/taos`. If the process lacks write permission there, you can either:
# 1. Set a different directory in `taos.cfg` (`logDir ...`), or
# 2. Run with `-o /dev/null` to discard logs.
docker run --rm -it tdengine/tdengine-tsdb-oss-client:3.3.7.5-alpine sh
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
