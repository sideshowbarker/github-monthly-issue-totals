#!/bin/bash

# This tool, run locally in a clone of a GitHub repo, and given a number of
# months N as an argument, uses the GitHub API to show — for the history of
# the last N months — a month-by-month listing of the total issues closed
# and opened and for each month, and the total PRs merged, closed, and
# opened for each month. And it shows related issue and PR averages over
# the given history, and the total increase or decrease in open issues and
# PRs over the given history.

remoteURLproperty=remote.origin.url
if [ -n "$(git config --get remote.upstream.url)" ]; then
  remoteURLproperty=remote.upstream.url
fi

repoURL=$(git config --get "$remoteURLproperty" | sed -r \
  's/.*(\@|\/\/)(.*)(\:|\/)([^:\/]*)\/([^\/\.]*)\.git/https:\/\/\2\/\4\/\5/')
orgAndRepo=$(echo "$repoURL" | rev | cut -d '/' -f-2 | rev)

searchBase="https://api.github.com/search/issues?q=repo:$orgAndRepo"

sleepseconds=${GITHUB_API_SLEEP_SECONDS:-6}

today=$(date +"%d %B %Y")

htmlFile=issue-totals.html
htmlFile=$(echo "$orgAndRepo" | tr '/' '-')-$(date +"%Y-%m-%d")-"$htmlFile"

hiEscape="\033[0;1m"
hi=$hiEscape
hiOff="\033[0m"

writeDualAxisGraphToHTMLFile() {
  LC_CTYPE="en_US.UTF-8"
  title=$1
  righttitle=$2
  lefttitle=$3
  shift 3
  printf '%s\n' "$@" | tac | cat - <(echo "e") \
    | gnuplot -p -e "\
      set term svg size 660,438 fixed font ',16'; \
      set xrange reverse;
      set ylabel '$lefttitle' tc lt 1;
      set ytics nomirror tc lt 1;
      set y2label '$righttitle' tc lt 2 rotate by 270;
      set y2tics tc lt 2;
      set xlabel 'Months before $today';
      set title '$title - $repoURL';
      set key left top font ',12';
      plot
      '-' with lines title '$lefttitle' axes x1y1 lw 2,
      '-' with lines title '$righttitle' axes x1y2 lw 2" \
        | tail -n +2 \
        | sed -r -e 's/ id="[^"]+"//g' \
        | sed -r -e "s/ id='[^']+'//g" >> "$htmlFile" \
        2> >( grep -v "Fontconfig warning" 1>&2)
}

if [ -z "$orgAndRepo" ]; then
  echo
  echo -n -e \
    "${hi}Error:${hiOff} This tool must be run from within a clone " >&2
  echo -e "of a GitHub repo. Stopping." >&2
  exit 1;
fi

if [ -n "$GITHUB_TOKEN" ]; then
  token="$GITHUB_TOKEN";
elif [ -n "$GH_TOKEN" ]; then
  token="$GH_TOKEN";
else
  echo
  echo -n -e \
    "${hi}Warning:${hiOff} No GITHUB_TOKEN or GH_TOKEN set. " >&2
  echo -e "Requests to will be unauthenticated." >&2
fi

if [ -n "$token" ]; then
  authorizationHeader="Authorization: token $GITHUB_TOKEN"
fi

issuesClosedArray=()
issuesOpenedArray=()
issuesDeltaArray=()
PRsMergedArray=()
PRsClosedArray=()
PRsMergedOrClosedArray=()
PRsOpenedArray=()
PRsDeltaArray=()

months=${1:-13} # if no command-line arg, show data for the last 13 months
[[ $months =~ ^[0-9]+$ ]] || months=13 # if arg not integer, default to 13
[ "$months" -gt 0 ] || months=13
date --date="" > /dev/null 2>&1 || hasGnuDate=$?
echo
echo -e " ${hi}$repoURL${hiOff}"
echo "┌────────────────┬─────────────────────┐"
echo "│     Issues     │         PRs         │"
echo "├────────────────┼─────────────────────┤"
echo "│ Clsd Opnd   +- │ Mrgd Clsd Opnd   +- │             Month range"
echo "├────────────────┼─────────────────────┼───────────────────────────────────────┐"

cat << EOF > "$htmlFile"
<!doctype html><html lang=en><meta charset=utf-8>
<title>$orgAndRepo - monthly issue and PR totals for $today</title>
<style>
  body { font-family: sans-serif; }
  body > div { display: flex; flex-flow: row wrap; padding-top: 20px }
  body > div { padding-top: 26px; border-top: 2px solid #ccc }
  body > div > div { padding: 2px 20px; }
  h1 { font-size: 28px; text-align: center; }
  h1, h2 { text-align: center; }
  table { width: 670px; height: 444px; margin-bottom: 16px }
  table { text-align: right; }
  thead { text-align: center; vertical-align: bottom }
  th, td { padding: 8px; }
  th { background: #999; font-size: .95em; color: white; }
  tbody tr { font-family: monospace; font-size: 13px }
  td { padding: 4px 8px; }
  td:nth-of-type(8n) { text-align: left; }
  tbody tr:nth-child(even) { background: #999; color: white; }
  code { color: orangered; font-size: 15px; font-weight: bold }
  svg { border: 1px solid #ccc; margin-top: 2px; margin-left: 6px }
</style>
<h1>Monthly issue and PR totals for $today</h1>
<h2><a href='$repoURL'>$repoURL</a></h2>
<div>
  <table>
    <thead>
      <tr>
        <th colspan=3>Issues
        <th colspan=4>PRs
        <th rowspan=2>Month range
      </tr>
      <tr>
        <th>Clsd
        <th>Opnd
        <th>+ -
        <th>Mrgd
        <th>Clsd
        <th>Opnd
        <th>+ -
    </thead>
EOF

for (( i=months - 1; i >= 0; i-- )); do
  if [ $i -ne $((months - 1)) ]; then
    sleep "$sleepseconds"
  fi
  hi=''
  [ $((i%2)) -eq 0 ] && hi=$hiEscape
  if [ "$hasGnuDate" != 1 ]; then
    startDate=$(date --date="$((i + 1)) month" +"%Y-%m-%d")
    endDate=$(date --date="$i month" +"%Y-%m-%d")
  else
    # BSD date(1) (used on, e.g., macOS)
    startDate="$(date -j -v+1d -f "%Y-%m-%d" \
      "$(date -v-"$((i + 1))"m +"%Y-%m-%d")" +"%Y-%m-%d")"
    endDate=$(date -v-"$i"m +"%Y-%m-%d")
  fi
  issuesClosed="$(printf "%4s" \
    "$(curl -H "$authorizationHeader" -fsSL \
    "$searchBase"+type:issue+closed:"$startDate".."$endDate" \
    | grep '^  "total_count"' | cut -d ':' -f2- | sed 's/,//' | xargs)")"
  issuesOpened="$(printf "%4s" \
    "$(curl -H "$authorizationHeader" -fsSL \
    "$searchBase"+type:issue+created:"$startDate".."$endDate" \
    | grep '^  "total_count"' | cut -d ':' -f2- | sed 's/,//' | xargs)")"
  issuesDelta=$(printf "%4s" $((issuesOpened - issuesClosed)))
  PRsMerged="$(printf "%4s" \
    "$(curl -H "$authorizationHeader" -fsSL \
    "$searchBase"+type:pr+merged:"$startDate".."$endDate" \
    | grep '^  "total_count"' | cut -d ':' -f2- | sed 's/,//' | xargs)")"
  PRsClosed="$(printf "%4s" \
    "$(curl -H "$authorizationHeader" -fsSL \
    "$searchBase"+type:pr+is:unmerged+closed:"$startDate".."$endDate" \
    | grep '^  "total_count"' | cut -d ':' -f2- | sed 's/,//' | xargs)")"
  PRsMergedOrClosed=$((PRsMerged + PRsClosed))
  PRsOpened="$(printf "%4s" \
    "$(curl -H "$authorizationHeader" -fsSL \
    "$searchBase"+type:pr+created:"$startDate".."$endDate" \
    | grep '^  "total_count"' | cut -d ':' -f2- | sed 's/,//' | xargs)")"
  PRsDelta=$(printf "%4s" $((PRsOpened - PRsMerged - PRsClosed)))
  issuesClosedArray+=("$issuesClosed")
  issuesOpenedArray+=("$issuesOpened")
  issuesDeltaArray+=("$issuesDelta")
  PRsMergedArray+=("$PRsMerged")
  PRsClosedArray+=("$PRsClosed")
  PRsMergedOrClosedArray+=("$PRsMergedOrClosed")
  PRsOpenedArray+=("$PRsOpened")
  PRsDeltaArray+=("$PRsDelta")
  echo -n -e "│ ${hi}$issuesClosed${hiOff}"
  echo -n -e " ${hi}$issuesOpened${hiOff}"
  echo -n -e " ${hi}$issuesDelta${hiOff} "
  echo -n -e "│ ${hi}$PRsMerged${hiOff}"
  echo -n -e " ${hi}$PRsClosed${hiOff}"
  echo -n -e " ${hi}$PRsOpened${hiOff}"
  echo -n -e " ${hi}$PRsDelta${hiOff} "

cat << EOF >> "$htmlFile"
    <tr>
      <td>$issuesClosed
      <td>$issuesOpened
      <td>$issuesDelta
      <td>$PRsMerged
      <td>$PRsClosed
      <td>$PRsOpened
      <td>$PRsDelta
EOF
  echo -n '    <td>' >> "$htmlFile"
  if [ "$hasGnuDate" != 1 ]; then
    echo -n -e "│ ${hi}$(date --date \
      "$(date --date="-$((i + 1)) month") +1 day" +"%b %d")"
    echo -n -e " to $(date --date="-$i month" +"%b %d %Y")"
    echo -n "$(date --date \
      "$(date --date="-$((i + 1)) month") +1 day" +"%b %d")" >> "$htmlFile"
    echo -n " – $(date --date="-$i month" +"%b %d %Y")" >> "$htmlFile"
  else
    # BSD date(1) (used on, e.g., macOS)
    echo -n -e "│ ${hi}$(date -j -v+1d -f "%Y-%m-%d" \
      "$(date -v-"$((i + 1))"m +"%Y-%m-%d")" +"%b %d")"
    echo -n -e " – $(date -v-"$i"m +"%b %d %Y")"
    echo -n "$(date -j -v+1d -f "%Y-%m-%d" \
      "$(date -v-"$((i + 1))"m +"%Y-%m-%d")" +"%b %d")" >> "$htmlFile"
    echo -n " – $(date -v-"$i"m +"%b %d %Y")" >> "$htmlFile"
  fi
  if [ "$i" -eq 0 ]; then
    echo -e " ending today${hiOff}     │"
    echo " ending today" >> "$htmlFile"
  else
    echo -e " ending $(printf "%-9s" $i"mo ago")${hiOff} │"
    echo " ending ${i}mo ago" >> "$htmlFile"
  fi
done

echo "└────────────────┴─────────────────────┴───────────────────────────────────────┘"
echo "  </table>" >> "$htmlFile"

averageIssuesClosed=$(($(total=0;
  for i in "${issuesClosedArray[@]}"; \
    do ((total+=i)); done; echo $total) / months))
averageIssuesOpened=$(($(total=0;
  for i in "${issuesOpenedArray[@]}"; \
    do ((total+=i)); done; echo $total) / months))
averageIssuesDelta=$(($(total=0;
  for i in "${issuesDeltaArray[@]}"; \
    do ((total+=i)); done; echo $total) / months))

averagePRsMerged=$(($(total=0;
  for i in "${PRsMergedArray[@]}"; \
    do ((total+=i)); done; echo $total) / months))
averagePRsClosed=$(($(total=0;
  for i in "${PRsClosedArray[@]}"; \
    do ((total+=i)); done; echo $total) / months))
averagePRsOpened=$(($(total=0;
  for i in "${PRsOpenedArray[@]}"; \
    do ((total+=i)); done; echo $total) / months))
averagePRsDelta=$(($(total=0;
  for i in "${PRsDeltaArray[@]}"; \
    do ((total+=i)); done; echo $total) / months))
averagePRsDelta=$(($(total=0;
  for i in "${PRsDeltaArray[@]}"; \
    do ((total+=i)); done; echo $total) / months))

hi=$hiEscape
if [ "$months" -gt 1 ]; then
  echo " For the last $months months:"
  echo

  echo -n -e "${hi}$(printf "%8s" $averageIssuesClosed)"
  echo -e " issues closed per month on average.${hiOff}"
  echo -n -e "$(printf "%8s" $averageIssuesOpened)"
  echo -e " issues opened per month on average."
  increaseOrDecrease="increase"
  if [[ $averageIssuesDelta -lt 0 ]]; then
    increaseOrDecrease="decrease"
  fi
  echo -n -e "${hi}$(printf "%8s" $averageIssuesDelta)"
  echo -e " issue $increaseOrDecrease in open issues per month on average."
  echo -ne "${hiOff}"

  echo
  echo -n -e "${hi}$(printf "%8s" $averagePRsMerged)"
  echo -e " PRs merged per month on average.${hiOff}"
  echo -n -e "$(printf "%8s" $averagePRsClosed)"
  echo -e " PRs closed (unmerged) per month on average."
  echo -n -e "${hi}$(printf "%8s" $averagePRsOpened)"
  echo -e " PRs opened per month on average.${hiOff}"
  increaseOrDecrease="increase"
  if [[ $averagePRsDelta -lt 0 ]]; then
    increaseOrDecrease="decrease"
  fi
  echo -n -e "$(printf "%8s" $averagePRsDelta)"
  echo -e " PR $increaseOrDecrease in open PRs per month on average."
fi

sleep "$sleepseconds"

echo
# Issue averages
issuesCurrentlyOpen="$(curl -H "$authorizationHeader" -fsSL \
  "$searchBase"+type:issue+state:open \
  | grep '^  "total_count"' | cut -d ':' -f2- | sed 's/,//' | xargs)"

totalIssuesOpened=$(total=0;
  for i in "${issuesOpenedArray[@]}"; \
    do ((total+=i)); done; echo $total)
totalIssuesClosed=$(total=0;
  for i in "${issuesClosedArray[@]}"; \
    do ((total+=i)); done; echo $total)

if [ "$months" -gt 1 ]; then
  netIssuesOpened=$((totalIssuesOpened - totalIssuesClosed))

  echo -n -e "$(printf "%4s" $netIssuesOpened) issue"
  increaseOrDecrease="increase"
  if [[ $netIssuesOpened -lt 0 ]]; then
    increaseOrDecrease="decrease"
  fi
  echo -n -e " $increaseOrDecrease"
  echo -n -e " in open issues in $((months - 1))"
  if [ "$months" -gt 2 ]; then
    echo -e " months. "
  else
    echo -e " month. "
  fi
fi
echo -e "$(printf "%4s" "$issuesCurrentlyOpen") issues currently open."

# PR averages
PRsCurrentlyOpen="$(curl -H "$authorizationHeader" -fsSL \
  "$searchBase"+type:pr+state:open \
  | grep '^  "total_count"' | cut -d ':' -f2- | sed 's/,//' | xargs)"

totalPRsClosed=$(total=0;
  for i in "${PRsClosedArray[@]}"; \
    do ((total+=i)); done; echo $total)
totalPRsMerged=$(total=0;
  for i in "${PRsMergedArray[@]}"; \
    do ((total+=i)); done; echo $total)
totalPRsOpened=$(total=0;
  for i in "${PRsOpenedArray[@]}"; \
    do ((total+=i)); done; echo $total)

echo -n -e "${hi}"
if [ "$months" -gt 1 ]; then
  netPRsOpened=$((totalPRsOpened - totalPRsMerged - totalPRsClosed))

  echo -n -e "$(printf "%4s" "$netPRsOpened") PR"
  increaseOrDecrease="increase"
  if [[ $netPRsOpened -lt 0 ]]; then
    increaseOrDecrease="decrease"
  fi
  echo -n -e " $increaseOrDecrease"
  echo -n -e " in open PRs in $((months - 1))"
  if [ "$months" -gt 2 ]; then
    echo -e " months. "
  else
    echo -e " month. "
  fi
fi
echo -e "$(printf "%4s" "$PRsCurrentlyOpen") PRs currently open."
echo -n -e "${hiOff}"

if [ ! "$(command -v gnuplot >/dev/null 2>&1; echo $?)" ]; then
cat << EOF >> "$htmlFile"
<p>
To see graphs, install <code>gnuplot</code> — e.g.,
with <code>apt install gnuplot</code> (Ubuntu),
or <code>brew install gnuplot</code> (macOS).
EOF
else
writeDualAxisGraphToHTMLFile "Increase/decrease in open issues/PRs" \
  "Increase/decrease in open PRs" "Increase/decrease in open issues" \
  "${PRsDeltaArray[@]}" "e" "${issuesDeltaArray[@]}"
writeDualAxisGraphToHTMLFile "Issues closed and opened per month" \
  "Issues opened" "Issues closed" \
  "${issuesOpenedArray[@]}" "e" "${issuesClosedArray[@]}"
writeDualAxisGraphToHTMLFile "PRs merged+closed and opened per month" \
  "PRs opened" "PRs merged+closed" \
  "${PRsOpenedArray[@]}" "e" "${PRsMergedOrClosedArray[@]}"
fi
