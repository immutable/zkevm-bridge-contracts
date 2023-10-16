eslint-config-richardpringle
========================

Baseline eslint config for richardpringle projects. A work in progress.

## Basic Usage

Add `eslint-config-richardpringle` to `devDependencies`.

    $ npm install -D github:richardpringle/eslint-config-richardpringle

Create/modify `.eslintrc` in the project's root to include:

```json
{
  "extends": "richardpringle"
}
```

## Advanced Usage

It is sometimes desirable to override some of these rules because a team
does not want to follow that particular rule for this repository:

```json
{
  "extends": "richardpringle",
  "rules": {
    "comma-dangle": 0
  }
}
```

In cases where these rules are being adopted but the code has many style
errors, it might be helpful to turn the worst errors into warnings until the
entire repo can be fixed:


```json
{
  "extends": "richardpringle",
  "rules": {
    "comma-dangle": 1,
  }
}
```

## Further Reading

- [eslint rules](http://eslint.org/docs/rules/)
- [eslint config](http://eslint.org/docs/user-guide/configuring)
