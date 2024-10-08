#!/bin/bash

# Path to sshd_config
SSHD_CONFIG="/etc/ssh/sshd_config"

trap 'echo "❌ An error occurred. Reverting changes..."; cp "$SSHD_CONFIG.bak" "$SSHD_CONFIG"; exit 1' ERR

# Function to apply changes and document them
apply_and_document_change() {
  local setting="$1"
  local new_value="$2"

  # Check if the setting already has the correct value
  if grep -q "^$setting $new_value" "$SSHD_CONFIG"; then
    if [ $? -ne 0 ]; then
      echo "❌ Failed to check current value of $setting"
      exit 1
    fi
    echo "🔄 $setting is already set to $new_value. Skipping..."
    return
  fi

  # Check if the setting exists and what its current value is
  if grep -q "^$setting" "$SSHD_CONFIG"; then
    if [ $? -ne 0 ]; then
      echo "❌ Failed to check current value of $setting"
      exit 1
    fi
    current_value=$(grep "^$setting" "$SSHD_CONFIG")
    sed -i "s/^$current_value$/$setting $new_value/" "$SSHD_CONFIG"
    if [ $? -ne 0 ]; then
      echo "❌ Failed to update $setting to $new_value"
      exit 1
    fi
  elif grep -q "^#$setting" "$SSHD_CONFIG"; then
    if [ $? -ne 0 ]; then
      echo "❌ Failed to check current value of $setting"
      exit 1
    fi
    current_value=$(grep "^#$setting" "$SSHD_CONFIG")
    sed -i "s/^$current_value$/$setting $new_value/" "$SSHD_CONFIG"
    if [ $? -ne 0 ]; then
      echo "❌ Failed to update $setting to $new_value"
      exit 1
    fi
  else
    echo "$setting $new_value" >> "$SSHD_CONFIG"
    if [ $? -ne 0 ]; then
      echo "❌ Failed to add $setting $new_value"
      exit 1
    fi
  fi

  # Double check the change
  if ! grep -q "^$setting $new_value" "$SSHD_CONFIG"; then
    if [ $? -ne 0 ]; then
      echo "❌ Failed to verify the change for $setting"
      exit 1
    fi
    echo "❌ Failed to apply $setting $new_value"
    exit 1
  else
    echo "✅ Applied $setting $new_value"
  fi
}

# Backup the original sshd_config file
echo "📂 Backing up the original sshd_config file..."
cp "$SSHD_CONFIG" "$SSHD_CONFIG.bak"
if [ $? -eq 0 ]; then
  echo "✅ Backup successful: $SSHD_CONFIG.bak"
else
  echo "❌ Backup failed"
  exit 1
fi
sleep 1

# Disable Root Login with Password
echo "🔧 Disabling root login with password..."
apply_and_document_change "PermitRootLogin" "prohibit-password"
sleep 1

# Ensure Password Authentication is Disabled
echo "🔧 Ensuring password authentication is disabled..."
apply_and_document_change "PasswordAuthentication" "no"
sleep 1

# Ensure Pubkey Authentication is Enabled (No change needed for commented line)
echo "🔧 Ensuring public key authentication is enabled..."
if ! grep -q "^PubkeyAuthentication yes" "$SSHD_CONFIG"; then
  if [ $? -ne 0 ]; then
    echo "❌ Failed to check current value of PubkeyAuthentication"
    exit 1
  fi
  apply_and_document_change "PubkeyAuthentication" "yes"
fi
sleep 1

# Restart SSH service
echo "🔄 Restarting SSH service..."
if systemctl restart sshd; then
  echo "✅ SSH service restarted successfully"
else
  echo "❌ Failed to restart SSH service"
  exit 1
fi
sleep 1

# Verify settings
verify_setting() {
  local setting="$1"
  local expected_value="$2"

  if ! grep -q "^$setting $expected_value" "$SSHD_CONFIG"; then
    if [ $? -ne 0 ]; then
      echo "❌ Failed to verify the setting for $setting"
      exit 1
    fi
    echo "❌ $setting is not set to $expected_value as expected"
    exit 1
  else
    echo "✅ $setting is correctly set to $expected_value"
  fi
}

echo "🔍 Verifying settings..."
verify_setting "PermitRootLogin" "prohibit-password"
sleep 1
verify_setting "PasswordAuthentication" "no"
sleep 1
verify_setting "PubkeyAuthentication" "yes"
sleep 1

echo "🎉 All settings are applied and verified successfully"
