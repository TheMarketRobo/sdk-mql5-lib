// Pinned mirror of ci.yml's commitlint ruleset. ci.yml runs:
//   npx --no-install commitlint -x @commitlint/config-conventional ...
// This file is the config-file form of that `-x` flag — keep them equivalent
// (change one only with the other, same PR; see tools/verify-local.sh header).
// verify-local.sh copies this file next to its throwaway npm install so the
// `extends` resolves against the packages installed there.
module.exports = { extends: ["@commitlint/config-conventional"] };
