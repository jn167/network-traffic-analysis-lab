# shellcheck shell=bash
# Shared safety check, sourced by the Kali scripts. Refuses any target outside
# the isolated lab network so none of this tooling can point at a real host.
lab_guard() {
    local t="$1"
    if [[ ! $t =~ ^10\.0\.50\.([0-9]{1,3})$ ]] || (( BASH_REMATCH[1] > 254 )); then
        echo "Refusing: '$t' is not a host in the lab network 10.0.50.0/24." >&2
        exit 1
    fi
}
