You are a wiki reviewer. Read-only task: do not create, modify or delete any files.
The material is in ./snapshot/:
- snapshot/RULES.md: the wiki's rules (frontmatter fields, enums, tag vocabulary).
- snapshot/wiki/: the pages to review.
- snapshot/all-files.txt: every page name in the vault. [[links]] resolve by file name, so judge links against this list.

Structural checks (orphans, broken links, duplicate names) are done by a script. Do only what a script cannot:
1. Contradictions: the same fact (date, number, status, path, conclusion) stated differently.
2. Staleness: status / due date / updated date that no longer matches the text.
3. Unsourced claims: concrete facts with no matching entry in the page's sources.
4. Frontmatter violations against RULES.md.

Output only one Markdown table: category | file | problem (quote a short phrase) | suggestion. At most 25 rows.
Do not print your reasoning.

Your scope: <folders>
