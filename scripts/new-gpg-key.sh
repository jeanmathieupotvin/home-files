# ~/new-gpg-key.sh: executed manually by user.

# Create a new GPG key and manipulate it.
# Sources:
#  - docs.github.com/en/authentication/managing-commit-signature-verification/checking-for-existing-gpg-keys
#  - docs.github.com/en/authentication/managing-commit-signature-verification/generating-a-new-gpg-key


# Manipulate existing keys -----------------------------------------------------


# List all keys and their IDs. They are stored in the ~/.gnupg directory.
# Key IDs are found next to sec (string after <algorithm>/).
gpg --list-secret-keys --keyid-format=long
gpg2 --list-secret-keys --keyid-format LONG # If you must use gpg2.

# List all keys, their IDs, and embedded photos.
gpg --list-secret-keys --keyid-format=long --list-options show-photos

# Export key. Get key id with command above.
gpg --armor --export <key-id> # copy contents of output.


# Create new key ---------------------------------------------------------------


# Enter command below and follow instruction.
# Kind: RSA and RSA.
# Size: 4096 bits.
# Key should not expire.
gpg --full-generate-key                      # version >= 2.1.17
gpg --default-new-key-algo rsa4096 --gen-key # version  < 2.1.17

# Check that key was generated. You should see something.
gpg --list-secret-keys --keyid-format=long


# Add a photo to a key ---------------------------------------------------------


gpg --edit-key <key-id>

# Then, type addphoto.
gpg > addphoto

# Then, type full path to a (small) JPEG image.
# Then, close image and enter y (image is correct).

# Then, save updated key.
gpg > save

# Verify that image is now listed in key.
gpg --list-secret-keys --keyid-format=long


# Remove a component from a key ------------------------------------------------


gpg --edit-key <key-id>

# Then, select a component by entering an integer or uuid.
gpg > <integer-or-string>

# Then, delete component.
gpg > deluid

# Then, save updated key.
gpg > save

# Verify that component was removed from key.
gpg --list-secret-keys --keyid-format=long


# Tell Git to use GPG signature ------------------------------------------------


git config --global commit.gpgSign true
git config --global user.signingKey <key-id>
