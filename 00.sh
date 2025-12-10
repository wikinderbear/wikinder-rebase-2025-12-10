#!/bin/bash
#
# Executed on December 10, 2025 (UTC):
#
# Squash commits by the specific authors into one (or as few as possible) per
# file, per author, per day (JST) using the `git rebase` command.
#
# 1) Rewrite "Revert <hash>...<hash> on <title>" commit messages to "Updated
#    <title> (markdown)" using `git rebase`, since commit hashes may change
#    after squashing.
# 2) Squash commits using `git rebase`.
# 3) Remove empty commits and restore the committer to match the original author
#    for every commit using `git-filter-repo`.
#
# Prerequisite: `git-filter-repo`
#

# Exit immediately if any command fails.
set -xeuo pipefail
IFS=$'\n\t'

command -v git-filter-repo

TIMESTAMP=$(date -u +'%Y-%m-%d')

PRODUCTION_REMOTE='https://github.com/wikinder/wikinder.wiki.git'
WORK_REMOTE="git@github.com:wikinderbear/wikinder-rebase-$TIMESTAMP.git"

BACKUP_BRANCH='backup-before-rebase'
BACKUP_TAG="$BACKUP_BRANCH-$TIMESTAMP"

FIRST_LOG='../01-git-log.txt'
FIRST_REBASE_TODO='../01-git-rebase-todo.txt'
SECOND_LOG='../02-git-log.txt'
SECOND_REBASE_TODO='../02-git-rebase-todo.txt'
THIRD_LOG='../03-git-log.txt'
FOURTH_LOG='../04-git-log.txt'

# Set the time zone to JST (UTC+9).
export TZ='Asia/Tokyo'

# Mirror the production repo.
git clone --mirror "$PRODUCTION_REMOTE" production-repo.git

# Create a work repo from the mirror.
git clone --branch master production-repo.git work-repo
cd work-repo
git remote remove origin
git remote add work-remote "$WORK_REMOTE"

# Create a backup branch from master (without switching).
git branch "$BACKUP_BRANCH" master

# Tag the latest commit on the backup branch.
git tag --annotate "$BACKUP_TAG" "$BACKUP_BRANCH" \
  --message="Backup before rebase ($TIMESTAMP)"

# Push the backup branch and tag to the work remote.
git push work-remote "$BACKUP_BRANCH" "$BACKUP_TAG"

# Configure `git log` to match the git rebase todo format.
git config --local log.date iso-strict-local
git config --local format.pretty 'pick %h # "%ad", "%an", "%s"'

# Write the initial log to a file.
git log --reverse > "$FIRST_LOG"

# Generate a rebase todo to rewrite "Revert" commit messages to "Updated".
perl ../01-revert-to-updated.pl "$FIRST_LOG" > "$FIRST_REBASE_TODO"

read -rp "$FIRST_REBASE_TODO created. Press Enter to perform the rebase..."

# Perform the first rebase.
git -c sequence.editor="cp '$FIRST_REBASE_TODO'" \
  rebase -i --root --committer-date-is-author-date

# Write the log after the first rebase.
git log --reverse > "$SECOND_LOG"

read -rp "First rebase complete. $SECOND_LOG created. Press Enter to continue..."

# Generate a rebase todo to squash commits.
perl ../02-squash.pl "$SECOND_LOG" > "$SECOND_REBASE_TODO"

read -rp "$SECOND_REBASE_TODO created. Press Enter to perform the rebase..."

# Perform the second rebase. Automatically recover from the error "you asked to
# amend the most recent commit, but doing so would make it empty" and continue
# rebasing.
git -c sequence.editor="cp '$SECOND_REBASE_TODO'" \
  rebase -i --root --committer-date-is-author-date \
  || { until git commit --amend --allow-empty --no-edit && git rebase --continue; do :; done }

# Write the log after the second rebase.
git log --reverse > "$THIRD_LOG"

read -rp "Second rebase complete. $THIRD_LOG created. Press Enter to run git-filter-repo..."

# Remove empty commits and restore the committer to match the original author
# for every commit.
git filter-repo --force --prune-empty=always --commit-callback '
  commit.committer_name  = commit.author_name
  commit.committer_email = commit.author_email
  commit.committer_date  = commit.author_date
'

# Write the log after `git-filter-repo`.
git log --reverse > "$FOURTH_LOG"

# Verify that all commits are in chronological order.
git log --reverse --format='%at' | sort -nc

read -rp "git-filter-repo complete. $FOURTH_LOG created. Press Enter to push master to the work remote..."

# Push master to the work remote.
git push work-remote master

exit 0

# Force push to the production remote.
# cd work-repo
# git remote add production-remote "$PRODUCTION_REMOTE"
# git push production-remote master --force
