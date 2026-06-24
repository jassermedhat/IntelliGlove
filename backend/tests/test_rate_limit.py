from app.rate_limit import InMemoryRateLimiter


def test_rate_limiter_releases_requests_after_the_window() -> None:
    limiter = InMemoryRateLimiter(requests=2, window_seconds=10)
    assert limiter.allow("client", now=0)
    assert limiter.allow("client", now=1)
    assert not limiter.allow("client", now=2)
    assert limiter.allow("client", now=11)
