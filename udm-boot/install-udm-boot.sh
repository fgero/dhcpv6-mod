#!/usr/bin/env sh

if [ $(ubnt-device-info firmware | sed 's#\..*$##g' || true) -lt 2 ]; then
  echo "ERROR: Unsupported firmware, must be 2.x or more" >&2
  exit 1
fi

SERVICE_NAME="udm-boot"
SYSTEMCTL_PATH="/lib/systemd/system/${SERVICE_NAME}.service"
SYMLINK_SYSTEMCTL="/etc/systemd/system/multi-user.target.wants/${SERVICE_NAME}.service"

echo "(re)installing UDM Boot service ${SERVICE_NAME} ..."

systemctl list-unit-files | grep '^'${SERVICE_NAME}'.service '
if [ $? -eq 0 ]; then
  echo "Disabling existing service ${SERVICE_NAME}..."
  systemctl disable ${SERVICE_NAME}
  systemctl daemon-reload
fi
rm -f "$SYMLINK_SYSTEMCTL"

echo "Creating systemctl ${SERVICE_NAME}.service file"
cp ${SERVICE_NAME}.service "$SYSTEMCTL_PATH"
sleep 1s

echo "Enabling ${SERVICE_NAME} service..."
systemctl daemon-reload
systemctl enable ${SERVICE_NAME}
systemctl start ${SERVICE_NAME}

if [ ! -e "$SYMLINK_SYSTEMCTL" ]; then
  echo
  echo "ERROR: Failed to install ${SERVICE_NAME} service" >&2
  exit 1
fi

echo
echo "===> UDM Boot installed as service ${SERVICE_NAME}, see status below"
echo

systemctl status ${SERVICE_NAME} --no-pager
