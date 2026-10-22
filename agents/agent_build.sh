#!/usr/bin/env bash
set -euo pipefail

variant=${1:-}
buildnum=${2:-}
ctr=haier_build
root=/data3/tinch/haier
src=/home/build/LA.VENDOR.13.2.6
image=iro/androidbuilder:u22
build_user=iro
force=${FORCE:-0}

[[ -d $root/LA.QSSI.13.0 && -d $root/LA.VENDOR.13.2.6 ]] || {
  echo "ERROR: source directories missing under $root" >&2
  exit 4
}
[[ -x $root/LA.VENDOR.13.2.6/MC940_A13_build.sh ]] || {
  echo "ERROR: build script missing: $root/LA.VENDOR.13.2.6/MC940_A13_build.sh" >&2
  exit 4
}
case "$variant" in
  user|userdebug) ;;
  *) echo "usage: $0 user|userdebug <buildnum>" >&2; exit 2 ;;
esac
[[ $buildnum =~ ^[0-9]+$ ]] || { echo "usage: $0 user|userdebug <buildnum>" >&2; exit 2; }

top=$(docker top "$ctr" 2>/dev/null || true)
if grep -qE 'MC940_A13_build\.sh' <<< "$top"; then
  if [[ "$force" != 1 ]]; then
    echo "ERROR: build is running in '$ctr'; use FORCE=1 to stop it." >&2
    exit 3
  fi
  echo "FORCE=1: stopping the running build"
fi

docker rm -f "$ctr" >/dev/null 2>&1 || true
trap 'docker rm -f "$ctr" >/dev/null 2>&1 || true' EXIT
docker run -d --privileged --name "$ctr" \
  -v "$root:/home/build" \
  -v "/home/$build_user/.ssh:/home/$build_user/.ssh" \
  "$image" sleep infinity >/dev/null

rc=0
docker exec "$ctr" su -l "$build_user" -s /bin/bash -c \
  "cd $src && ./MC940_A13_build.sh $variant kalama $buildnum > build.log 2>&1" || rc=$?
echo "BUILD_EXIT=$rc"
exit "$rc"