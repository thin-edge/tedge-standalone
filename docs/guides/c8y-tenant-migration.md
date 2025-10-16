# Moving a device to another Cumulocity Tenant

## Devices using Basic Authentication

### Option 1: Keeping the same device password

The following shows how to move an existing device to a new tenant whilst keeping the same password, but just changing the Cumulocity Tenant ID part of the username (e.g. `txxxx/`) to the new Cumulocity Tenant ID.

1. In the new tenant, pre-register the device using the same external id and password

    **Example using go-c8y-cli**

    ```sh
    c8y deviceregistration register-basic \
        --id "<device_external_id>" \
        --name "<name>" \
        --password '<password>'
    ```

2. Send a command to the device (e.g. a c8y_Command operation) with the following script (typically done via the Cumulocity Device Management Application). Update the `NEW_TENANT_ID` and `NEW_C8Y_URL` values to match the tenant 

    **Warning** You MUST be 100% sure that the tenant ID and url are correct, otherwise it will lead to the device being disconnected with no way of recovering the device remotely.

    ```sh
    set -e

    NEW_TENANT_ID="txxx"
    NEW_C8Y_URL="example.cumulocity.com"

    # import settings
    INSTALL_DIR=/data/tedge
    if [ ! -f "$INSTALL_DIR/env" ]; then
        echo "Could not find the shell env file. path=$INSTALL_DIR/env. Check the 'INSTALL_DIR' variable and try again";
        exit 1;
    fi
    . "$INSTALL_DIR/env"


    # Replace the tenant id in the credentials.toml
    CREDENTIALS_PATH=$(tedge config get c8y.credentials_path)
    sed -i "s|username = \"t[0-9]\+/|username = \"${NEW_TENANT_ID}/|" "$CREDENTIALS_PATH"

    # set the new Cumulocity URL
    tedge config set c8y.url "$NEW_C8Y_URL"

    # delete the entity store (in the future there will be an api call to clear the cache)
    rm -f "$INSTALL_DIR/.agent/entity_store.jsonl"

    # Runit specific command to restart the tedge-mapper-c8y service
    # Note: This will leave the operation on the current tenant in EXECUTING indefinitely
    sv restart tedge-mapper-c8y
    ```

    **Notes**

    * The operation in the current tenant will remain in the "executing" state indefinitely as the connection with the current tenant is severed during the script. Alternatively, you could remove the `sv restart` command, and perform a full device restart.
