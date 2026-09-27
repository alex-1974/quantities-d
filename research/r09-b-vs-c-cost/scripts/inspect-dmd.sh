#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ROOT}/results/dmd-inspect"
mkdir -p "${OUT}"

build_and_capture() {
    local config="$1"
    local target="probe-${config}"
    local binary="${ROOT}/${target}"

    (
        cd "${ROOT}"
        dub build --compiler=dmd --config="${config}" --build=release --force
    )

    cp "${binary}" "${OUT}/${target}"
    cp "${binary}" "${OUT}/${target}.stripped"
    strip "${OUT}/${target}.stripped"

    size -A -d "${OUT}/${target}" > "${OUT}/${target}.sections.txt"
    size -A -d "${OUT}/${target}.stripped" > "${OUT}/${target}.stripped.sections.txt"

    nm -S --size-sort --demangle "${OUT}/${target}" \
        > "${OUT}/${target}.nm.txt"

    objdump -d -C "${OUT}/${target}" \
        > "${OUT}/${target}.asm.txt"
}

build_and_capture b
build_and_capture c

{
    echo '=== FILE SIZE ==='
    stat -c '%n %s' "${OUT}/probe-b" "${OUT}/probe-c" \
        "${OUT}/probe-b.stripped" "${OUT}/probe-c.stripped"

    echo
    echo '=== SECTION DIFF (unstripped) ==='
    diff -u "${OUT}/probe-c.sections.txt" "${OUT}/probe-b.sections.txt" || true

    echo
    echo '=== SECTION DIFF (stripped) ==='
    diff -u "${OUT}/probe-c.stripped.sections.txt" \
        "${OUT}/probe-b.stripped.sections.txt" || true

    echo
    echo '=== LARGEST B SYMBOLS ==='
    tail -n 40 "${OUT}/probe-b.nm.txt"

    echo
    echo '=== LARGEST C SYMBOLS ==='
    tail -n 40 "${OUT}/probe-c.nm.txt"
} | tee "${OUT}/report.txt"

echo
echo "Detailed artifacts: ${OUT}"
