# Compare Version Numbers in BASH

Version numbers aren't numbers exactly. They are a form of numbers but they aren't numbers that are directly comparable by standard language operations. Version numbers **require** code to compare. I don't like it but here we are.

If you're on this page you need BASH to compare version numbers. I am sorry. But you do have some options.

I say the best approach here is to lean on the sort command. It already knows how to sort things and it has a lot of options.

## The problems

### We need to sort a bunch of versions and find the latest

[versions.txt](./versions.txt)

```bash
$ cat versions.txt
2.1.10
2.1.3
2.10.0
2.1.8
2.1.9
2.10.0-101
1.1.1
2.9.9
2.10.0-21
```

We need to find `2.10.0-101`

### We need to compare two versions

e.g. BAD version has a security vulnerability

We need to return "safe" if our discovered version is greater than `$_bad_version` and "DANGER" if not.

```bash
$ export _bad_version=2.17.38

# against each of these versions in turn
2.15.3     # DANGER
2.17.37    # DANGER
2.17.38    # DANGER
2.17.38-1  # safe
2.17.39    # safe
```

## sort -V

If you have a modern version of `sort` this problem is already solved for you.

```bash
-V, --version-sort
  Sort version numbers. The input lines are treated as file names in form
  PREFIX VERSION SUFFIX, where SUFFIX matches the regular expression
  "(.([A-Za-z~][A-Za-z0-9~]*)?)*". The files are compared by their prefixes and
  versions (leading zeros are ignored in version numbers, see example below).
  If an input string does not match the pattern, then it is compared using the
  byte compare function. All string comparisons are performed in C locale, the
  locale environment setting is ignored.

  Example:

  $ ls sort* | sort -V

  sort-1.022.tgz

  sort-1.23.tgz

  sort-1.23.1.tgz

  sort-1.024.tgz

  sort-1.024.003.

  sort-1.024.003.tgz

  sort-1.024.07.tgz

  sort-1.024.009.tgz
```

It really sorts! Let's throw it at our problems.

### sort -V to sort versions

```bash
$ cat versions.txt | sort -V
1.1.1
2.1.3
2.1.8
2.1.9
2.1.10
2.9.9
2.10.0
2.10.0-21
2.10.0-101
```

```bash
$ cat versions.txt | sort -V | tail -1
2.10.0-101
```

Sort! We love you!

### sort -V to compare two versions

Here's the deal in a one liner. In real life you'd replace `echo "$_current_version"` with whatever you have that outputs a version. e.g. `printable-ascii --version`.

```bash
$ sort -V <(echo "$_bad_version") <(echo "$_current_version") | tail -1 | read -r latest && if [[ "$latest" == "$_bad_version" ]]; then echo "DANGER"; else echo "safe"; fi
```

And expanded into a script: [compare-versions.sh](./compare-versions.sh)

```bash
#!/usr/bin/env bash

compare() {
  local _bad_version=$1
  local _current_version=$2
  local _latest

  _latest=$(sort -V <(echo "$_bad_version") <(echo "$_current_version") | tail -1)

  [[ "$_latest" == "$_bad_version" ]] && echo "DANGER" && return

  echo "safe"
}

compare "$@"
```

The gist: sort the known bad version with the current version. If we get the bad version back as the latest version when we know we either match or precede the bad version. If we don't then we know the current version comes after the bad version.

Run against our samples of "current version"

```bash
$ export _bad_version=2.17.38

$ ./compare-versions.sh "$_bad_version" 2.15.3      # DANGER
$ ./compare-versions.sh "$_bad_version" 2.17.37     # DANGER
$ ./compare-versions.sh "$_bad_version" 2.17.38     # DANGER
$ ./compare-versions.sh "$_bad_version" 2.17.38-1   # safe
$ ./compare-versions.sh "$_bad_version" 2.17.39     # safe
```

Is `sort` the best or what?

But what if you can't depend on recent versions of sort?

## sort -tk

```bash
-k field1[,field2], --key=field1[,field2]
  Define a restricted sort key that has the starting position field1, and
  optional ending position field2 of a key field. The -k option may be
  specified multiple times, in which case subsequent keys are compared when
  earlier keys compare equal. The -k option replaces the obsolete options +pos1
  and -pos2, but the old notation is also supported.

-t char, --field-separator=char
  Use char as a field separator character. The initial char is not considered
  to be part of a field when determining key offsets. Each occurrence of char
  is significant (for example, ``charchar'' delimits an empty field). If -t is
  not specified, the default field separator is a sequence of blank space
  characters, and consecutive blank spaces do not delimit an empty field,
  however, the initial blank space is considered part of a field when
  determining key offsets. To use NUL as field separator, use -t '\0'.
```

Using sort's `-t` and `-k` options allow us to teach sort how to compare the things we've got. If we can assume that `.` characters will always separate our versions and if we can assume we'll only have four parts of versions then this relatively simple command will work.

```bash
$ sort -t. -k 1,1n -k 2,2n -k 3,3n -k 4,4n
```

Now we have to get a little greasy. You can see in our versions above that we sometimes have `-` characters as part of the version.

One option we have is to agree that we can convert those `-` characters to `.` and then compare directly with sort. The consequence will be that versions like `2.10.0-101` will be output as `2.10.0.101`. If we can live with that then great!

### sort -tk to sort versions

```bash
$ cat versions.txt | tr - . | sort -t. -k 1,1n -k 2,2n -k 3,3n -k 4,4n
1.1.1
2.1.3
2.1.8
2.1.9
2.1.10
2.9.9
2.10.0
2.10.0.21
2.10.0.101
```

```bash
$ cat versions.txt | tr - . | sort -t. -k 1,1n -k 2,2n -k 3,3n -k 4,4n | tail -1
2.10.0.101
```

### sort -tk to compare two versions

The one-liner

```
$ sort -t. -k 1,1n -k 2,2n -k 3,3n -k 4,4n <(echo "$_bad_version" | tr - .) <(echo "$_current_version" | tr - .) | tail -1 | read -r latest && if [[ "$latest" == "$_bad_version" ]]; then echo "DANGER"; else echo "safe"; fi
```

The script version: [compare-versions--sort-tk.sh](./compare-versions--sort-tk.sh)

```bash
#!/usr/bin/env bash

comparable() {
  echo "$1" | tr - .
}

compare() {
  local _bad_version
  local _current_version
  local _latest

  _bad_version=$(comparable "$1")
  _current_version=$(comparable "$2")
  _latest=$(sort -t. -k 1,1n -k 2,2n -k 3,3n -k 4,4n <(echo "$_bad_version") <(echo "$_current_version") | tail -1)

  [[ "$_latest" == "$_bad_version" ]] && echo "DANGER" && return

  echo "safe"
}

compare "$@"
```

```bash
$ export _bad_version=2.17.38

$ ./compare-versions.sh "$_bad_version" 2.15.3      # DANGER
$ ./compare-versions.sh "$_bad_version" 2.17.37     # DANGER
$ ./compare-versions.sh "$_bad_version" 2.17.38     # DANGER
$ ./compare-versions.sh "$_bad_version" 2.17.38-1   # safe
$ ./compare-versions.sh "$_bad_version" 2.17.39     # safe
```

Thanks `sort`!
