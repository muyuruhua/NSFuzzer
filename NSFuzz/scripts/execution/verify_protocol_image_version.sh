#!/bin/bash

set -euo pipefail

IMAGE="${1:-}"
if [[ -z "${IMAGE}" ]]; then
  echo "[version-check] Usage: $0 <docker-image>"
  exit 2
fi

REPO="${IMAGE%%:*}"

protocol=""
expected=""
probe_cmd=""

if [[ "${REPO}" == lightftp* ]]; then
  protocol="lightftp"
  expected="v2.0-11-g5980ea1"
  probe_cmd='git -C /home/ubuntu/experiments/LightFTP describe --tags --always 2>/dev/null || true'
elif [[ "${REPO}" == bftpd* ]]; then
  protocol="bftpd"
  if [[ "${IMAGE}" == "bftpd-nsfuzz:v5.7-backup" ]]; then
    expected="5.7"
  else
    expected="6.1"
  fi
  probe_cmd='grep -E "^VERSION=" /home/ubuntu/experiments/bftpd/Makefile.in 2>/dev/null | head -n1 | cut -d= -f2 || true'
elif [[ "${REPO}" == proftpd* ]]; then
  protocol="proftpd"
  expected="v1.3.7rc3-218-g4017eff"
  probe_cmd='git -C /home/ubuntu/experiments/proftpd describe --tags --always 2>/dev/null || true'
elif [[ "${REPO}" == pure-ftpd* ]]; then
  protocol="pure-ftpd"
  expected="1.0.49"
  probe_cmd='git -C /home/ubuntu/experiments/pure-ftpd describe --tags --always 2>/dev/null || true'
elif [[ "${REPO}" == exim* ]]; then
  protocol="exim"
  expected="exim-4_89"
  probe_cmd='git -C /home/ubuntu/experiments/exim describe --tags --always 2>/dev/null || true'
elif [[ "${REPO}" == live555* ]]; then
  protocol="live555"
  expected="ceeb4f4"
  probe_cmd='git -C /home/ubuntu/experiments/live555 rev-parse --short HEAD 2>/dev/null || true'
elif [[ "${REPO}" == kamailio* ]]; then
  protocol="kamailio"
  expected="sr_3.1_freeze-17570-g2648eb3"
  probe_cmd='git -C /home/ubuntu/experiments/kamailio describe --tags --always 2>/dev/null || true'
elif [[ "${REPO}" == forked-daapd* ]]; then
  protocol="forked-daapd"
  expected="27.2"
  probe_cmd='git -C /home/ubuntu/experiments/forked-daapd describe --tags --always 2>/dev/null || true'
elif [[ "${REPO}" == lighttpd1* ]] || [[ "${REPO}" == lighttpd* ]]; then
  protocol="lighttpd1"
  expected="AC_INIT=1.4.72;GIT=lighttpd-1.4.71-1-g9f38b63c"
  probe_cmd='ac=$(grep -Eo "AC_INIT\(\[lighttpd\],\[[0-9.]+\]" /home/ubuntu/experiments/lighttpd1/configure.ac 2>/dev/null | head -n1 | sed -E "s/.*\[([0-9.]+)\]$/\1/"); gd=$(git -C /home/ubuntu/experiments/lighttpd1 describe --tags --always 2>/dev/null || true); echo "AC_INIT=${ac};GIT=${gd}"'
elif [[ "${REPO}" == mosquitto* ]]; then
  protocol="mosquitto"
  expected="libmosquitto.so.1.6.8"
  probe_cmd='if [[ -f /home/ubuntu/experiments/mosquitto/lib/libmosquitto.so.1.6.8 ]]; then echo "libmosquitto.so.1.6.8"; else ls -1 /home/ubuntu/experiments/mosquitto/lib/libmosquitto.so.* 2>/dev/null | xargs -r -n1 basename; fi'
fi

if [[ -z "${protocol}" ]]; then
  echo "[version-check] skip: ${IMAGE} (no pinned mapping)"
  exit 0
fi

if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  echo "[version-check] fail: image not found -> ${IMAGE}"
  exit 1
fi

actual="$(docker run --rm "${IMAGE}" /bin/bash -lc "${probe_cmd}" | tr -d '\r' | head -n1)"

if [[ -z "${actual}" ]]; then
  echo "[version-check] fail: ${IMAGE} (${protocol}) has empty version probe"
  echo "[version-check] expected: ${expected}"
  exit 1
fi

ok=0
if [[ "${protocol}" == "lighttpd1" ]]; then
  [[ "${actual}" == *"AC_INIT=1.4.72"* && "${actual}" == *"GIT=lighttpd-1.4.71-1-g9f38b63c"* ]] && ok=1
elif [[ "${protocol}" == "mosquitto" ]]; then
  [[ "${actual}" == "libmosquitto.so.1.6.8" ]] && ok=1
else
  [[ "${actual}" == "${expected}" ]] && ok=1
fi

if [[ ${ok} -ne 1 ]]; then
  echo "[version-check] fail: ${IMAGE} (${protocol}) version mismatch"
  echo "[version-check] expected: ${expected}"
  echo "[version-check] actual:   ${actual}"
  exit 1
fi

echo "[version-check] ok: ${IMAGE} (${protocol}) -> ${actual}"
