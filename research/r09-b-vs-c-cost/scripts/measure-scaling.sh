#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ROOT}/results/scaling"
GEN="${OUT}/generated"
RUNS="${RUNS:-3}"
POINTS=(1 5 10 20 50 100 200)

mkdir -p "${GEN}"
rm -f "${OUT}/summary.tsv"

printf 'compiler\tmodel\tn_types\trun\telapsed_s\tmax_rss_kb\tbinary_bytes\tstripped_bytes\tquantity_symbols\ttypeinfo_symbols\txop_equals\txto_hash\n' > "${OUT}/summary.tsv"

generate_source() {
    local model="$1"
    local n="$2"
    local file="${GEN}/app_${model}_${n}.d"
    {
        echo "module app_${model}_${n};"
        echo
        if [[ "${model}" == b ]]; then
            echo 'struct QuantityB(Spec, Unit, Rep) { Rep value; }'
        else
            echo 'struct QuantityC(Spec, Rep) { Rep value; }'
        fi
        echo
        echo 'struct Spec0 {}'
        for ((i=0; i<n; ++i)); do
            echo "struct Unit${i} {}"
        done
        echo
        if [[ "${model}" == b ]]; then
            for ((i=0; i<n; ++i)); do
                echo "alias Q${i} = QuantityB!(Spec0, Unit${i}, double);"
                echo "__gshared Q${i} q${i};"
            done
        else
            echo 'alias Q = QuantityC!(Spec0, double);'
            echo '__gshared Q q;'
            for ((i=0; i<n; ++i)); do
                echo "@safe pure nothrow @nogc Q fromUnit${i}(double value) { return Q(value); }"
            done
        fi
        echo
        echo 'double kernel() {'
        echo '    double sum = 0.0;'
        if [[ "${model}" == b ]]; then
            for ((i=0; i<n; ++i)); do
                echo "    q${i}.value = ${i}.0;"
                echo "    sum += q${i}.value;"
            done
        else
            for ((i=0; i<n; ++i)); do
                echo "    q = fromUnit${i}(${i}.0);"
                echo '    sum += q.value;'
            done
        fi
        echo '    return sum;'
        echo '}'
        echo
        echo 'void main() {'
        echo '    import core.stdc.stdio : printf;'
        echo '    printf("%.0f\\n", kernel());'
        echo '}'
    } > "${file}"
}

measure_one() {
    local compiler="$1" model="$2" n="$3" run="$4"
    local src="${GEN}/app_${model}_${n}.d"
    local bin="${GEN}/probe-${compiler}-${model}-${n}"
    local stripped="${bin}.stripped"
    local timefile="${GEN}/${compiler}-${model}-${n}-${run}.time"
    local nmfile="${GEN}/${compiler}-${model}-${n}.nm"

    rm -f "${bin}" "${stripped}"

    if [[ "${compiler}" == dmd ]]; then
        /usr/bin/time -f '%e\t%M' -o "${timefile}" \
            dmd -O -release -inline -boundscheck=off -of="${bin}" "${src}"
    else
        /usr/bin/time -f '%e\t%M' -o "${timefile}" \
            ldc2 -O3 -release -boundscheck=off -of="${bin}" "${src}"
    fi

    cp "${bin}" "${stripped}"
    strip "${stripped}"
    nm -S --size-sort --demangle "${bin}" > "${nmfile}"

    local elapsed rss bytes stripped_bytes qsymbols typeinfos equals hashes
    IFS=$'\t' read -r elapsed rss < "${timefile}"
    bytes="$(stat -c '%s' "${bin}")"
    stripped_bytes="$(stat -c '%s' "${stripped}")"
    if [[ "${model}" == b ]]; then
        qsymbols="$(grep -c 'QuantityB!' "${nmfile}" || true)"
    else
        qsymbols="$(grep -c 'QuantityC!' "${nmfile}" || true)"
    fi
    typeinfos="$(grep -c 'TypeInfo_S.*Quantity' "${nmfile}" || true)"
    equals="$(grep -c 'Quantity.*__xopEquals' "${nmfile}" || true)"
    hashes="$(grep -c 'Quantity.*__xtoHash' "${nmfile}" || true)"

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "${compiler}" "${model}" "${n}" "${run}" "${elapsed}" "${rss}" \
        "${bytes}" "${stripped_bytes}" "${qsymbols}" "${typeinfos}" "${equals}" "${hashes}" \
        >> "${OUT}/summary.tsv"
}

for n in "${POINTS[@]}"; do
    generate_source b "${n}"
    generate_source c "${n}"
done

for compiler in dmd ldc2; do
    for n in "${POINTS[@]}"; do
        for run in $(seq 1 "${RUNS}"); do
            if (( run % 2 == 1 )); then models=(b c); else models=(c b); fi
            for model in "${models[@]}"; do
                echo "=== ${compiler} / ${model} / N=${n} / run ${run} ==="
                measure_one "${compiler}" "${model}" "${n}" "${run}"
            done
        done
    done
done

echo
echo '=== RAW SCALING SUMMARY ==='
column -t -s $'\t' "${OUT}/summary.tsv"
echo
echo "Results: ${OUT}/summary.tsv"
