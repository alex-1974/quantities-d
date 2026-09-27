#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ROOT}/results/typeinfo"
GEN="${OUT}/generated"
POINTS=(1 20 100 200)
mkdir -p "${GEN}"
rm -f "${OUT}/summary.tsv"

printf 'variant\tn\tbinary_bytes\tstripped_bytes\tquantity_symbols\ttypeinfo\txop_equals\txto_hash\n' > "${OUT}/summary.tsv"

generate() {
    local variant="$1" n="$2" file="${GEN}/${variant}_${n}.d"
    {
        echo "module ${variant}_${n};"
        echo 'struct Spec {}'
        for ((i=0; i<n; ++i)); do echo "struct Unit${i} {}"; done
        case "${variant}" in
            baseline)
                echo 'struct Quantity(Spec, Unit, Rep) { Rep value; }'
                ;;
            explicit)
                cat <<'D'
struct Quantity(Spec, Unit, Rep)
{
    Rep value;

    bool opEquals(ref const Quantity rhs) const @safe pure nothrow @nogc
    {
        return value == rhs.value;
    }

    size_t toHash() const @safe pure nothrow @nogc
    {
        static if (Rep.sizeof == size_t.sizeof)
        {
            union Bits { Rep value; size_t bits; }
            return Bits(value).bits;
        }
        else
            return 0;
    }
}
D
                ;;
            noeq)
                cat <<'D'
struct Quantity(Spec, Unit, Rep)
{
    Rep value;

    @disable bool opEquals(ref const Quantity rhs) const;
}
D
                ;;
        esac
        for ((i=0; i<n; ++i)); do
            echo "alias Q${i} = Quantity!(Spec, Unit${i}, double);"
            echo "__gshared Q${i} q${i};"
        done
        echo 'double kernel() {'
        echo '    double sum;'
        for ((i=0; i<n; ++i)); do
            echo "    q${i}.value = ${i}.0;"
            echo "    sum += q${i}.value;"
        done
        echo '    return sum;'
        echo '}'
        echo 'void main() { import core.stdc.stdio : printf; printf("%.0f\\n", kernel()); }'
    } > "${file}"
}

measure() {
    local variant="$1" n="$2"
    local src="${GEN}/${variant}_${n}.d" bin="${GEN}/${variant}_${n}"
    local nmfile="${bin}.nm"
    dmd -O -release -inline -boundscheck=off -of="${bin}" "${src}"
    cp "${bin}" "${bin}.stripped"
    strip "${bin}.stripped"
    nm -S --size-sort --demangle "${bin}" > "${nmfile}"

    local bytes stripped q ti eq hash
    bytes="$(stat -c '%s' "${bin}")"
    stripped="$(stat -c '%s' "${bin}.stripped")"
    q="$(grep -c 'Quantity!' "${nmfile}" || true)"
    ti="$(grep -c 'TypeInfo_S.*Quantity' "${nmfile}" || true)"
    eq="$(grep -c 'Quantity.*__xopEquals' "${nmfile}" || true)"
    hash="$(grep -c 'Quantity.*__xtoHash' "${nmfile}" || true)"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n'         "${variant}" "${n}" "${bytes}" "${stripped}" "${q}" "${ti}" "${eq}" "${hash}"         >> "${OUT}/summary.tsv"
}

for n in "${POINTS[@]}"; do
    for variant in baseline explicit noeq; do
        echo "=== ${variant} / N=${n} ==="
        generate "${variant}" "${n}"
        if ! measure "${variant}" "${n}"; then
            printf '%s\t%s\tCOMPILE-FAIL\tCOMPILE-FAIL\t-\t-\t-\t-\n' "${variant}" "${n}" >> "${OUT}/summary.tsv"
        fi
    done
done

echo
echo '=== TYPEINFO ISOLATION SUMMARY ==='
column -t -s $'\t' "${OUT}/summary.tsv"
echo
echo "Results: ${OUT}/summary.tsv"
