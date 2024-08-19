# Bypassing `secrets initialize` command

Users may want to do so when copying existing files from an older distibution
to a new one. Before doing so, they are a couple of steps to perform. They
assume all required environment variables are set as expected.

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
