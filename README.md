# Bypassing `secrets initialize` command

Users may want to do so when copying existing files from an older distibution
to a new one.

## Problem

Before doing so, they are a couple of steps to perform. They
assume all required environment variables are set as expected.

## Solution

The first step is to install required dependencies.

```bash
sudo apt update
sudo apt upgrade
sudo apt install cryptsetup -y
```

Then, you need to update the ownership of the directory containing decrypted
secrets.

```bash
printenv # optional, but it is safer to double check
sudo chown -R "$USER:$USER" "$SECRETS_DIR"
```

The `-R` flag ensures all further subdirectories and files within your secret
directory (at once).

Then, simply execute command `secrets unlock`. It should proceed smoothly.

# Installing R from source

I usually follow
[instructions given by Posit](https://docs.posit.co/resources/install-r-source.html)
to install R from source. This allows me to have multiple concurrent versions of
R installed and to have better control over them.

## Problem

As of August 20<sup>th</sup>, 2024, Posit recommends installing required build
dependencies first with the following commands.

```bash
sudo sed -i.bak "/^#.*deb-src.*universe$/s/^# //g" /etc/apt/sources.list
sudo apt update
sudo apt build-dep r-base
```

**This does not work on versions of Ubuntu greater than or equal to `24.04`.**

The `sed` call is a little bit cryptic. However, all it does is activate source
dependencies maintained by the community in APT. It does so by *uncommenting*
`universe` components of `deb-src` lines in file `/etc/apt/sources.list`.
Ubuntu disallows them by default.

## Solution

The workaround on Ubuntu `24.04` (or greater) is simple. First, open file
`/etc/apt/sources.list.d/ubuntu.sources` with a text editor.

```bash
sudo nano /etc/apt/sources.list.d/ubuntu.sources
```

Then, append `deb-src` to `Types` of URI `http://archive.ubuntu.com/ubuntu` and
ensure that `universe` is listed in its `Components`. The full entry should
look like below.

```
Types: deb deb-src
URIs: http://archive.ubuntu.com/ubuntu
Suites: noble noble-updates noble-backports
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
```

Save and close the file. Then, run the following commands.

```bash
sudo apt update
sudo apt upgrade
sudo apt build-dep r-base
```

Afterwards, you may follow usual Posit instructions starting at section
[Specify R version](https://docs.posit.co/resources/install-r-source.html#specify-r-version).
