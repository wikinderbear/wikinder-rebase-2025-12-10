#!/usr/bin/env perl
#
# Generate a git rebase todo from a git log to rewrite "Revert <hash>...<hash>
# on <title>" commit messages to "Updated <title> (markdown)".
#
use strict;
use warnings;

# Read a git log line by line.
while (<>) {
    # Print the line as is.
    print;

    # Strip the newline.
    chomp;

    # Extract fields.
    my ($datetime, $message) =
        /^pick [0-9a-f]{7} # "(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+09:00)", ".+?", "(.*)"$/
        or die "line $.: $_";

    # Handle "Revert" commits.
    if ($message =~ /^Revert [0-9a-f]{40}\.\.\.[0-9a-f]{40} on (.+)$/) {
        my $title = $1;

        # Print an `exec` command to amend the commit message, specifying the
        # same author date and committer date as the original author date.
        my $new_message = "Updated $title (markdown)";
        printf(
            "exec GIT_COMMITTER_DATE='%s' git commit --amend --date='%s' --message='%s'\n",
            $datetime,
            $datetime,
            $new_message,
        );
    }
}
