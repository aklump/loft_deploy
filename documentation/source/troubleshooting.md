# Troubleshooting

## Trouble Connecting to Prod or Staging

You may need force a load of _~/.profile_ by using the `production.ssh` configuration.

## Getting Error: `mysqldump: Error: 'Access denied; you need (at least one of) the PROCESS privilege(s) for this operation' when trying to dump tablespaces`

1. Open _loft_deploy.yml_ and find `mysqldump_flags`
2. Copy that section including value.
3. On the server where this error shows up run `ldp config`
4. Add the copied value.
5. Append the value `no-tablespaces`, so it looks somewhat like this:

```yaml
mysqldump_flags:
  - single-transaction
  - skip-lock-tables
  - no-tablespaces
```

[Learn more](https://anothercoffee.net/how-to-fix-the-mysqldump-access-denied-process-privilege-error/)
