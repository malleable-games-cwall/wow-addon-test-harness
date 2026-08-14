#!/usr/bin/env bash
# Build a self contained `wowtest` binary with luastatic.
#
# Usage: scripts/build-binary.sh [output-directory]
#
# Requires: luastatic, a C compiler and a static Lua library (liblua*.a).
# LUA_A / LUA_INCLUDE_DIR / CC may be set to override autodetection.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out_dir="${1:-${repo_root}/dist}"
build_dir="${repo_root}/build"

find_lua_static_library() {
  if [[ -n "${LUA_A:-}" ]]; then
    echo "${LUA_A}"
    return
  fi
  local candidate
  for candidate in \
    /usr/lib/*/liblua5.4.a /usr/lib/*/liblua5.3.a /usr/lib/*/liblua5.1.a \
    /usr/lib/liblua5.4.a /usr/lib/liblua5.3.a /usr/lib/liblua5.1.a \
    /usr/local/lib/liblua5.4.a /usr/local/lib/liblua5.3.a /usr/local/lib/liblua.a \
    /opt/homebrew/lib/liblua5.4.a /opt/homebrew/lib/liblua.a; do
    if [[ -f "${candidate}" ]]; then
      echo "${candidate}"
      return
    fi
  done
  echo "error: no static Lua library found; set LUA_A" >&2
  exit 1
}

find_lua_include_dir() {
  if [[ -n "${LUA_INCLUDE_DIR:-}" ]]; then
    echo "${LUA_INCLUDE_DIR}"
    return
  fi
  local candidate
  for candidate in \
    /usr/include/lua5.4 /usr/include/lua5.3 /usr/include/lua5.1 \
    /usr/local/include/lua5.4 /usr/local/include /opt/homebrew/include; do
    if [[ -f "${candidate}/lua.h" ]]; then
      echo "${candidate}"
      return
    fi
  done
  echo "error: lua.h not found; set LUA_INCLUDE_DIR" >&2
  exit 1
}

lua_a="$(find_lua_static_library)"
lua_include="$(find_lua_include_dir)"

rm -rf "${build_dir}"
mkdir -p "${build_dir}/wowharness/api" "${out_dir}"

# luastatic derives module names from file paths, so `init.lua` has to become
# `wowharness.lua` for `require("wowharness")` to resolve inside the binary.
cp "${repo_root}"/src/wowharness/*.lua "${build_dir}/wowharness/"
cp "${repo_root}"/src/wowharness/api/*.lua "${build_dir}/wowharness/api/"
mv "${build_dir}/wowharness/init.lua" "${build_dir}/wowharness.lua"
cp "${repo_root}/bin/wowtest.lua" "${build_dir}/wowtest.lua"

cd "${build_dir}"
luastatic \
  wowtest.lua \
  wowharness.lua \
  wowharness/*.lua \
  wowharness/api/*.lua \
  "${lua_a}" \
  -I"${lua_include}" \
  -o wowtest

binary="wowtest"
if [[ -f "wowtest.exe" ]]; then
  binary="wowtest.exe"
fi
mv "${binary}" "${out_dir}/${binary}"
echo "built ${out_dir}/${binary} (lua: ${lua_a})"
