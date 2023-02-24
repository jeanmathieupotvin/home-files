# ~/new-ssh-key.sh: executed manually by user.

# Create a new SSH key, add it to the agent, and manipulate it.
# Sources:
#  - docs.github.com/en/authentication/connecting-to-github-with-ssh/checking-for-existing-ssh-keys
#  - docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
#  - docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account


# Manipulate existing keys -----------------------------------------------------


# List keys stored in usual ~/.ssh directory.
ls -al ~/.ssh

# Get SHA-256 fingerprint of a key (preferred, standard).
ssh-keygen -lf <path-to-pub-key>

# Get fingerprints of keys held by ssh-agent.
ssh-add -l

# Get other fingerprints.
ssh-keygen -E <md5|sha1|...> -lf <path-to-pub-key>

# Export key.
cat <path-to-key> # copy output.


# Create new key ---------------------------------------------------------------


# Create a new key.
ssh-keygen -t ed25519 -a 100 -C "jm@potvin.xyz"         # ED25519, preferred
ssh-keygen -t rsa -b 4096 -o -a 100 -C "jm@potvin.xyz"  # RSA

# Add key to ssh-agent.
eval "$(ssh-agent -s)"
ssh-add <path-to-private-key-file>

# Verify if all good. Key should be listed.
ssh-add -l
