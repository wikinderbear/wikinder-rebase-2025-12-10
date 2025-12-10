#!/usr/bin/env perl
#
# Generate a git rebase todo from a git log to squash commits by the specific
# authors into one (or as few as possible) per file, per author, per day.
#
use strict;
use warnings;

# Groups of commits to squash. Each element is a `[pick, fixup...]` group that
# will become a single squashed commit.
my @squash_groups;

# Metadata for the last group seen for each title.
my %last_seen;

# Read a git log line by line.
while (<>) {
    # Strip the newline.
    chomp;

    # Extract fields.
    my ($hash, $datetime, $day, $author, $message) =
        /^pick ([0-9a-f]{7}) # "((\d{4}-\d{2}-\d{2})T\d{2}:\d{2}:\d{2}\+09:00)", "(.+?)", "(.*)"$/
        or die "line $.: $_";

    # Extract title. Fallback to hash if no match.
    my ($title) = $message =~ /^(?:Created|Updated) (.+) \(markdown\)$/;
    $title ||= $hash;

    # Check if this commit can be squashed into the last group for the title.
    my $seen = $last_seen{$title};
    if (
        $seen
        and $seen->{day} eq $day
        and $seen->{author} eq $author
        and $author =~ /^(?:yuuki|bear)$/
    ) {
        # Squashable: append to the existing group.
        s/^pick/fixup/;
        push @{ $squash_groups[ $seen->{index} ] }, { line => $_, datetime => $datetime };
    }
    else {
        # Create a new group.
        push @squash_groups, [ { line => $_, datetime => $datetime } ];

        $last_seen{$title} = {
            index  => $#squash_groups,
            day    => $day,
            author => $author,
        };
    }
}

# Sort groups by their last commit's date.
@squash_groups = sort { $a->[-1]{datetime} cmp $b->[-1]{datetime} } @squash_groups;

# Output groups.
for my $group (@squash_groups) {
    for my $i (0 .. $#{$group}) {
        my $commit = $group->[$i];
        print $commit->{line}, "\n";

        # After the last fixup in the group, amend the author and committer
        # dates to that fixup's date.
        if ($commit->{line} =~ /^fixup/ and $i == $#{$group}) {
            printf(
                "exec GIT_COMMITTER_DATE='%s' git commit --amend --date='%s' --allow-empty --no-edit\n",
                $commit->{datetime},
                $commit->{datetime},
            );
        }
    }
}
