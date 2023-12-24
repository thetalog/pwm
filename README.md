# pwm Password Manager

## Overview

`pwm` is a simple bash script that serves as a password manager. It provides functionalities to store, retrieve, edit, and remove passwords securely. The script utilizes OpenSSL for key generation and encryption.

## Features

- **Password Storage**: Save passwords securely using asymmetric encryption.
- **Key Management**: Generate and manage private and public keys for password encryption.
- **Password Retrieval**: Retrieve passwords by providing the associated key.
- **Password Modification**: Edit existing passwords, update labels, and maintain modification history.
- **Password Removal**: Remove passwords securely, with automatic ID reordering.

## Prerequisites

- Ensure that OpenSSL is installed on your system.
- The script requires elevated privileges (`sudo`) to create and manipulate files in system directories.

## Installation

1. Clone the repository:

   ```bash
   git clone <repository-url>
   ```

2. Navigate to the project directory:

   ```bash
   cd <project-directory>
   ```

3. Make the script executable:

   ```bash
   chmod +x pwm.sh
   ```

## Usage

```bash
./pwm.sh <argument> [options]
```

### Arguments

- `--get <key>`: Retrieve the password associated with the given key.
- `--save <key> <password> <label>`: Save a new password with the provided key, password, and optional label.
- `--edit <old-key> <new-key> <new-label>`: Edit an existing password, updating the key and label.
- `--remove <key>`: Remove a password associated with the given key.
- `--help`: Display the help menu.

## Examples

- Save a password:

  ```bash
  ./pwm.sh --save email mysecretpassword WorkEmail
  ```

- Retrieve a password:

  ```bash
  ./pwm.sh --get email
  ```

- Edit a password:

  ```bash
  ./pwm.sh --edit email newemail PersonalEmail
  ```

- Remove a password:

  ```bash
  ./pwm.sh --remove email
  ```

## Notes

- Ensure that the script is executed with the necessary permissions.
- Use the `--help` option to display the help menu and understand available commands.

**Note:** This script is designed for educational purposes and may require adaptation for use in a production environment. Use it responsibly and at your own risk.
