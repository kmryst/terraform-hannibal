module.exports = {
  extends: ["@commitlint/config-conventional"],
  rules: {
    "type-enum": [
      2,
      "always",
      ["feat", "fix", "docs", "refactor", "test", "chore", "ci", "infra"],
    ],
    "subject-case": [0],
    "header-max-length": [2, "always", 100],
  },
};
