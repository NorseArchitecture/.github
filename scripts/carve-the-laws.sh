#!/usr/bin/env bash
#
# carve-the-laws.sh
#
# Applies the "Law of the Aesir" branch ruleset to every repository in the
# Norse Architecture organization. Idempotent: if a ruleset with the same
# name already exists on a repo, it is updated in place; otherwise created.
#
# Requirements:
#   - gh CLI authenticated with an account that has admin on the repos
#     (gh auth status to verify; needs "repo" scope / admin:org not required)
#
# Usage:
#   ./carve-the-laws.sh           # apply to all repos listed below
#   ./carve-the-laws.sh Asgard    # apply to a single repo
#
set -euo pipefail

ORG='NorseArchitecture'
RULESET_NAME='Law of the Aesir'

# The founding realms. Add new repos here as they are born.
ALL_REPOS=('Asgard' 'Svartalfheim' 'Midgard' 'Yggdrasil' 'Urdarbrunnr' 'Bifrost' 'Glitnir' '.github')

REPOS=("$@")
if [[ ${#REPOS[@]} -eq 0 ]]; then
	REPOS=("${ALL_REPOS[@]}")
fi

# ---------------------------------------------------------------------------
# The law itself.
#
# Notes on the choices encoded here:
#   - required_approving_review_count: 0 — solo-maintainer mode. The PR
#     workflow (no direct push, CI green, threads resolved) is enforced
#     without self-approval theater. Raise to 1+ when a second contributor
#     arrives.
#   - bypass_actors actor_id 5 = Repository admin role. bypass_mode
#     "always" lets an admin push directly in an emergency; change to
#     "pull_request" to allow bypass only through a PR.
#   - required_status_checks context "CI / build / build" was confirmed
#     empirically 2026-06-25 from Svartalfheim's first PR gate run:
#     "CI" = caller workflow name, first "build" = caller job id,
#     second "build" = called job id in ci-build-test.yml.
#   - deletion + non_fast_forward: nobody deletes or force-pushes the
#     default branch. Including you. Especially at 2 AM.
# ---------------------------------------------------------------------------
RULESET=$(cat <<'EOF'
{
	"name": "Law of the Aesir",
	"target": "branch",
	"enforcement": "active",
	"conditions": {
		"ref_name": {
			"include": ["~DEFAULT_BRANCH"],
			"exclude": []
		}
	},
	"bypass_actors": [
		{
			"actor_id": 5,
			"actor_type": "RepositoryRole",
			"bypass_mode": "always"
		}
	],
	"rules": [
		{ "type": "deletion" },
		{ "type": "non_fast_forward" },
		{
			"type": "pull_request",
			"parameters": {
				"required_approving_review_count": 0,
				"dismiss_stale_reviews_on_push": true,
				"require_code_owner_review": false,
				"require_last_push_approval": false,
				"required_review_thread_resolution": true
			}
		},
		{
			"type": "required_status_checks",
			"parameters": {
				"strict_required_status_checks_policy": true,
				"required_status_checks": [
					{ "context": "CI / build / build" }
				]
			}
		}
	]
}
EOF
)

# ---------------------------------------------------------------------------
# Apply: update if a ruleset of the same name exists, create otherwise.
# ---------------------------------------------------------------------------
FAILURES=()

for REPO in "${REPOS[@]}"; do
	echo "==> $ORG/$REPO"

	EXISTING_ID=$(gh api "repos/$ORG/$REPO/rulesets" \
		--jq ".[] | select(.name == \"$RULESET_NAME\") | .id" 2>/dev/null || true)

	if [[ -n "$EXISTING_ID" ]]; then
		echo "    Law already carved (ruleset $EXISTING_ID) — re-inscribing..."
		if echo "$RULESET" | gh api --method PUT "repos/$ORG/$REPO/rulesets/$EXISTING_ID" --input - > /dev/null; then
			echo "    Updated."
		else
			echo "    FAILED to update." >&2
			FAILURES+=("$REPO")
		fi
	else
		echo "    Carving the law anew..."
		if echo "$RULESET" | gh api --method POST "repos/$ORG/$REPO/rulesets" --input - > /dev/null; then
			echo "    Created."
		else
			echo "    FAILED to create." >&2
			FAILURES+=("$REPO")
		fi
	fi
done

echo
if [[ ${#FAILURES[@]} -gt 0 ]]; then
	echo "The Aesir were defied in: ${FAILURES[*]}" >&2
	exit 1
fi

echo 'The laws are carved. Verify with:'
echo "  gh ruleset list -R $ORG/Asgard"
