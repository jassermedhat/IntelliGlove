from __future__ import annotations

import logging
import os
import socket


def _is_in_docker() -> bool:
    """True when the process is running inside a Docker container."""
    return os.path.exists('/.dockerenv') or bool(os.getenv('RUNNING_IN_DOCKER'))


def _env_override() -> str | None:
    """Return the LAN_IP env var when explicitly set, otherwise None."""
    return os.getenv('LAN_IP', '').strip() or None


def _all_ipv4s() -> list[str]:
    """Collect every non-loopback IPv4 address assigned to this machine."""
    ips: list[str] = []
    try:
        _, _, addrs = socket.gethostbyname_ex(socket.gethostname())
        ips.extend(a for a in addrs if not a.startswith('127.'))
    except OSError:
        pass
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(('8.8.8.8', 80))
            routed = s.getsockname()[0]
            if not routed.startswith('127.') and routed not in ips:
                ips.append(routed)
    except OSError:
        pass
    return ips


def best_ip_for_client(client_ip: str) -> str:
    """Return our IP on the same /24 subnet as *client_ip*.

    Falls back to detect_lan_ip() when running inside Docker (where
    request.client.host is the Docker bridge gateway, not the real caller).
    """
    if override := _env_override():
        return override
    parts = client_ip.split('.')
    if len(parts) == 4:
        prefix = '.'.join(parts[:3]) + '.'
        for ip in _all_ipv4s():
            if ip.startswith(prefix):
                return ip
    return detect_lan_ip()


def detect_lan_ip() -> str:
    """Return the LAN IP most likely reachable from phones on the same network.

    Used for the startup log (no client IP available yet).  Prefers real WiFi
    adapters over Docker bridge / VPN virtual adapters.
    """
    if override := _env_override():
        return override

    if _is_in_docker():
        try:
            # Docker Desktop (Windows/Mac) registers this so containers can
            # reach the host.  May still return a Docker-internal IP on some
            # setups — set LAN_IP in the env to override.
            return socket.gethostbyname('host.docker.internal')
        except OSError:
            pass

    candidates = _all_ipv4s()

    # Known virtual adapter ranges to deprioritise.
    _virtual = ('172.', '192.168.65.', '192.168.64.')

    for prefix in ('192.168.', '10.'):
        for ip in candidates:
            if ip.startswith(prefix) and not any(ip.startswith(v) for v in _virtual):
                return ip

    for ip in candidates:
        if not ip.startswith('127.'):
            return ip

    return '127.0.0.1'


def log_startup_urls(port: int = 8000) -> None:
    ip = detect_lan_ip()
    log = logging.getLogger('intelliglove.startup')
    log.info('Detected LAN IP: %s', ip)
    log.info('Backend available at: http://%s:%d', ip, port)
    log.info('API docs at:         http://%s:%d/docs', ip, port)
