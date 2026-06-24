from __future__ import annotations

from sqlalchemy import select

from app.admin_identity import ensure_admin_record
from app.models import AuditLog
from tests.conftest import auth_headers


def sync(client, token: str) -> dict:
    response = client.post("/api/v1/auth/sync", headers=auth_headers(token), json={})
    assert response.status_code == 200
    return response.json()["data"]


def make_admin(client) -> None:
    sync(client, "admin-user")
    db = client.app.state.session_factory()
    try:
        ensure_admin_record(
            db,
            firebase_uid="firebase-admin",
            email="admin@example.com",
            name="Admin User",
        )
    finally:
        db.close()


def test_report_submission_and_admin_workflow(client) -> None:
    profile = sync(client, "verified-user")
    bug = client.post(
        "/api/v1/reports",
        headers=auth_headers(),
        json={
            "type": "bug",
            "message": "The translation button stopped responding.",
            "appVersion": "1.0.0",
            "deviceInfo": {"platform": "android"},
        },
    )
    assert bug.status_code == 201
    assert bug.json()["data"]["userId"] == profile["id"]
    report_id = bug.json()["data"]["reportId"]

    denied = client.get("/api/v1/admin/reports/bugs", headers=auth_headers())
    assert denied.status_code == 403
    assert denied.json()["code"] == "ADMIN_REQUIRED"

    make_admin(client)
    listed = client.get(
        "/api/v1/admin/reports/bugs", headers=auth_headers("admin-user")
    )
    assert listed.status_code == 200
    assert listed.json()["data"][0]["reportId"] == report_id
    updated = client.patch(
        f"/api/v1/admin/reports/{report_id}",
        headers=auth_headers("admin-user"),
        json={"status": "reviewed", "adminNotes": "Reproduced."},
    )
    assert updated.status_code == 200
    assert updated.json()["data"]["status"] == "reviewed"
    assert updated.json()["data"]["adminNotes"] == "Reproduced."

    db = client.app.state.session_factory()
    try:
        audit = db.scalar(select(AuditLog).where(AuditLog.action == "report.update"))
        assert audit
        assert audit.details["adminNotesChanged"] is True
    finally:
        db.close()


def test_bug_and_feedback_lists_are_separate(client) -> None:
    sync(client, "verified-user")
    for report_type in ("bug", "feedback"):
        assert client.post(
            "/api/v1/reports",
            headers=auth_headers(),
            json={"type": report_type, "message": f"A valid {report_type} message"},
        ).status_code == 201
    make_admin(client)
    bugs = client.get(
        "/api/v1/admin/reports/bugs", headers=auth_headers("admin-user")
    ).json()["data"]
    feedback = client.get(
        "/api/v1/admin/reports/feedback", headers=auth_headers("admin-user")
    ).json()["data"]
    assert [row["type"] for row in bugs] == ["bug"]
    assert [row["type"] for row in feedback] == ["feedback"]
