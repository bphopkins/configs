#!/usr/bin/env bash
# tl-compare.sh <oldlabel> <newlabel>
#
# Diff two tl-check.sh runs and classify every difference by severity.
#
# Documents that failed under BOTH releases are pre-existing breakage and are
# excluded -- they say nothing about the new release. Only changes that cross
# the old/new boundary are reported.
#
# Note on "TEXT CHANGED, layout stable": this is usually NOT a regression.
# Newer releases fix glyph-to-Unicode mappings, so symbols that previously
# extracted as garbage start extracting correctly. Confirm with tl-visdiff.sh
# before treating any of these as a problem.
set -uo pipefail

SP="${TL_STATE:-$HOME/.cache/tl-newyear}"
OLD="${1:?usage: tl-compare.sh <oldlabel> <newlabel>}"
NEW="${2:?usage: tl-compare.sh <oldlabel> <newlabel>}"
A="$SP/results-$OLD.tsv"
B="$SP/results-$NEW.tsv"

for f in "$A" "$B"; do
  [ -f "$f" ] || { echo "missing results file: $f" >&2; exit 1; }
done

awk -F'\t' -v OLD="$OLD" -v NEW="$NEW" '
  FNR==NR {
    st[$6]=$1; pg[$6]=$2; hs[$6]=$3; wn[$6]=$4; er[$6]=$5
    next
  }
  {
    p=$6
    if (!(p in st)) { added[++na]=p; next }
    o_st=st[p]; o_pg=pg[p]; o_hs=hs[p]; o_wn=wn[p]; o_er=er[p]
    n_st=$1;    n_pg=$2;    n_hs=$3;    n_wn=$4;    n_er=$5

    if (o_st != "ok" && n_st != "ok") { preexist++; next }

    short=p; sub(/^.*\/Desktop\//,"",short)

    if (o_st == "ok" && n_st != "ok") {
      regress[++nr] = sprintf("  %-7s -> %-7s  %s", o_st, n_st, short); next
    }
    if (o_st != "ok" && n_st == "ok") {
      fixed[++nf] = sprintf("  %-7s -> %-7s  %s", o_st, n_st, short); next
    }
    if (o_pg != n_pg) {
      pages[++np] = sprintf("  %5s -> %-5s pages  %s", o_pg, n_pg, short); next
    }
    if (o_er != n_er) {
      errs[++ne] = sprintf("  %3s -> %-3s errors  %s", o_er, n_er, short); next
    }
    if (o_hs != n_hs) {
      text[++nt] = sprintf("  text differs (same page count)  %s", short); next
    }
    if (n_wn > o_wn) {
      warns[++nw] = sprintf("  %3s -> %-3s warnings  %s", o_wn, n_wn, short); next
    }
    identical++
  }
  END {
    printf "\n===== %s -> %s =====\n", OLD, NEW

    printf "\n## REGRESSIONS (compiled before, broken now): %d\n", nr
    for (i=1;i<=nr;i++) print regress[i]; if (nr==0) print "  none"

    printf "\n## PAGE COUNT CHANGED: %d\n", np
    for (i=1;i<=np;i++) print pages[i]; if (np==0) print "  none"

    printf "\n## ERROR COUNT CHANGED: %d\n", ne
    for (i=1;i<=ne;i++) print errs[i]; if (ne==0) print "  none"

    printf "\n## TEXT CHANGED, layout stable: %d  (verify with tl-visdiff.sh)\n", nt
    for (i=1;i<=nt;i++) print text[i]; if (nt==0) print "  none"

    printf "\n## NEW WARNINGS ONLY: %d\n", nw
    for (i=1;i<=nw;i++) print warns[i]; if (nw==0) print "  none"

    printf "\n## NEWLY FIXED: %d\n", nf
    for (i=1;i<=nf;i++) print fixed[i]; if (nf==0) print "  none"

    if (na > 0) {
      printf "\n## NEW DOCUMENTS (not in baseline): %d\n", na
      for (i=1;i<=na;i++) print "  " added[i]
    }

    printf "\n----- byte-identical output: %d\n", identical
    printf "----- broken under both (pre-existing, ignored): %d\n", preexist
    printf "\nVERDICT: "
    if (nr==0 && np==0 && ne==0) print "CLEAN -- no document regressed"
    else printf "REVIEW NEEDED -- %d regressions, %d page changes, %d error changes\n", nr, np, ne
  }
' "$A" "$B"
