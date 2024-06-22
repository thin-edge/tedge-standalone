
PACKAGE := "tedge-standalone"

# Package files
package:
    tar czvf "{{PACKAGE}}.tar.gz" --owner=0 --group=0 --no-same-owner --no-same-permissions -C src ./tedge

