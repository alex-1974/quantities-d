#!/usr/bin/env bash
set -euo pipefail

RUNS="${RUNS:-5}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ROOT}/results"
RAW="${OUT}/raw"

mkdir -p "${RAW}"
rm -f "${RAW}"/*.time "${OUT}/summary.tsv"

printf 'compiler\tconfig\trun\telapsed_s\tmax_rss_kb\tbinary_bytes\tstripped_bytes\n' \
    > "${OUT}/summary.tsv"

compiler_version() {
    "$1" --version | head -n 1
}

measure_one() {
    local compiler="$1"
    local config="$2"
    local run="$3"
    local time_file="${RAW}/${compiler}-${config}-${run}.time"
    local target="probe-${config}"
    local binary="${ROOT}/${target}"

    rm -f "${binary}" "${binary}.stripped"

    (
        cd "${ROOT}"
        /usr/bin/time -f '%e\t%M' -o "${time_file}" \
            dub build \
                --compiler="${compiler}" \
                --config="${config}" \
                --build=release \
                --force
    )

    test -x "${binary}"

    local binary_bytes
    binary_bytes="$(stat -c '%s' "${binary}")"

    cp "${binary}" "${binary}.stripped"
    strip "${binary}.stripped"

    local stripped_bytes
    stripped_bytes="$(stat -c '%s' "${binary}.stripped")"

    local elapsed rss
    IFS=$'\t' read -r elapsed rss < "${time_file}"

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "${compiler}" "${config}" "${run}" "${elapsed}" "${rss}" \
        "${binary_bytes}" "${stripped_bytes}" \
        >> "${OUT}/summary.tsv"
}

{
    echo '# R09 environment'
    echo
    echo "date: $(date --iso-8601=seconds)"
    echo "uname: $(uname -a)"
    echo "dub: $(dub --version)"
    echo "dmd: $(compiler_version dmd)"
    echo "ldc2: $(compiler_version ldc2)"
    echo "runs: ${RUNS}"
} > "${OUT}/environment.txt"

for compiler in dmd ldc2; do
    for run in $(seq 1 "${RUNS}"); do
        if (( run % 2 == 1 )); then
            configs=(b c)
        else
            configs=(c b)
        fi

        for config in "${configs[@]}"; do
            echo "=== ${compiler} / ${config} / run ${run} ==="
            measure_one "${compiler}" "${config}" "${run}"
        done
    done
done

echo
echo '=== ENVIRONMENT ==='
cat "${OUT}/environment.txt"
echo
echo '=== RAW SUMMARY ==='
column -t -s $'\t' "${OUT}/summary.tsv"
