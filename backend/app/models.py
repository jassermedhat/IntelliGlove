from __future__ import annotations

from datetime import date, datetime, timezone
from typing import Any
from uuid import UUID, uuid4

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow, nullable=False
    )


class User(TimestampMixin, Base):
    __tablename__ = "users"
    __table_args__ = (
        CheckConstraint("role IN ('user', 'admin')", name="role"),
        CheckConstraint("status IN ('active', 'disabled')", name="status"),
    )

    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    firebase_uid: Mapped[str] = mapped_column(String(128), unique=True, index=True)
    email: Mapped[str] = mapped_column(String(254), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(100))
    role: Mapped[str] = mapped_column(String(20), default="user")
    email_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    photo_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="active")
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    devices: Mapped[list[Device]] = relationship(back_populates="user")
    sessions: Mapped[list[TranslationSession]] = relationship(back_populates="user")


class AdminUser(Base):
    __tablename__ = "admin_users"

    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), unique=True, index=True
    )
    firebase_uid: Mapped[str] = mapped_column(String(128), unique=True)
    email: Mapped[str] = mapped_column(String(254), unique=True)
    role: Mapped[str] = mapped_column(String(20), default="admin")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class Device(TimestampMixin, Base):
    __tablename__ = "devices"
    __table_args__ = (
        UniqueConstraint("user_id", "device_name", name="device_user_name"),
        CheckConstraint(
            "connection_status IN ('disconnected', 'scanning', 'connecting', 'connected', 'error')",
            name="connection_status",
        ),
        CheckConstraint("battery_level IS NULL OR (battery_level >= 0 AND battery_level <= 100)", name="battery"),
        CheckConstraint("signal_strength IS NULL OR (signal_strength >= 0 AND signal_strength <= 5)", name="signal"),
    )

    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    device_name: Mapped[str] = mapped_column(String(100))
    hardware_id: Mapped[str | None] = mapped_column(String(128), unique=True, nullable=True)
    connection_status: Mapped[str] = mapped_column(String(30), default="disconnected")
    connected_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_seen: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    firmware_version: Mapped[str | None] = mapped_column(String(50))
    battery_level: Mapped[int | None] = mapped_column(Integer)
    signal_strength: Mapped[int | None] = mapped_column(Integer)

    user: Mapped[User] = relationship(back_populates="devices")


class TranslationSession(TimestampMixin, Base):
    __tablename__ = "sessions"
    __table_args__ = (
        CheckConstraint("status IN ('active', 'closed', 'failed')", name="status"),
        Index(
            "uq_sessions_one_active_per_user",
            "user_id",
            unique=True,
            postgresql_where=text("status = 'active'"),
        ),
    )

    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    session_id: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    device_id: Mapped[UUID | None] = mapped_column(ForeignKey("devices.id", ondelete="SET NULL"))
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    status: Mapped[str] = mapped_column(String(20), default="active")
    source: Mapped[str | None] = mapped_column(String(30), nullable=True)
    translated_letters_count: Mapped[int] = mapped_column(Integer, default=0)
    total_readings: Mapped[int] = mapped_column(Integer, default=0)
    average_confidence: Mapped[float | None] = mapped_column(Float)

    user: Mapped[User] = relationship(back_populates="sessions")
    translations: Mapped[list[TranslationHistory]] = relationship(back_populates="session", passive_deletes=True)


class MlModel(TimestampMixin, Base):
    __tablename__ = "models"
    __table_args__ = (
        CheckConstraint("status IN ('available', 'invalid', 'archived')", name="status"),
        Index(
            "uq_models_one_active",
            "is_active",
            unique=True,
            postgresql_where=text("is_active = true"),
        ),
    )

    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    model_id: Mapped[str] = mapped_column(String(100), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(150))
    file_path: Mapped[str] = mapped_column(String(500), unique=True)
    labels_path: Mapped[str | None] = mapped_column(String(500))
    version: Mapped[str | None] = mapped_column(String(80))
    status: Mapped[str] = mapped_column(String(20), default="available")
    is_active: Mapped[bool] = mapped_column(Boolean, default=False)
    metadata_json: Mapped[dict[str, Any] | None] = mapped_column("metadata", JSONB)


class TranslationHistory(TimestampMixin, Base):
    __tablename__ = "translation_history"
    __table_args__ = (
        CheckConstraint("source IN ('live', 'mock_seed', 'manual_test')", name="source"),
        CheckConstraint("confidence IS NULL OR (confidence >= 0 AND confidence <= 1)", name="confidence"),
    )

    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    entry_id: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    session_id: Mapped[UUID] = mapped_column(ForeignKey("sessions.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    device_id: Mapped[UUID | None] = mapped_column(ForeignKey("devices.id", ondelete="SET NULL"))
    timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
    raw_input: Mapped[dict[str, Any]] = mapped_column(JSONB)
    translated_text: Mapped[str] = mapped_column(Text)
    gesture_label: Mapped[str | None] = mapped_column(String(100))
    language_code: Mapped[str] = mapped_column(String(20), default="en-US")
    confidence: Mapped[float | None] = mapped_column(Float)
    model_id: Mapped[UUID | None] = mapped_column(ForeignKey("models.id", ondelete="SET NULL"))
    source: Mapped[str] = mapped_column(String(20), default="live")

    session: Mapped[TranslationSession] = relationship(back_populates="translations")


class HealthMonitorData(Base):
    __tablename__ = "health_monitor_data"
    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    device_id: Mapped[UUID | None] = mapped_column(ForeignKey("devices.id", ondelete="SET NULL"))
    timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
    metrics: Mapped[dict[str, Any]] = mapped_column(JSONB)
    source: Mapped[str] = mapped_column(String(30), default="device")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class SmartHouseData(TimestampMixin, Base):
    __tablename__ = "smart_house_data"
    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    device_name: Mapped[str] = mapped_column(String(100))
    device_type: Mapped[str] = mapped_column(String(60))
    state: Mapped[dict[str, Any]] = mapped_column(JSONB)
    source: Mapped[str] = mapped_column(String(30), default="user")


class AnalyticsData(TimestampMixin, Base):
    __tablename__ = "analytics_data"
    __table_args__ = (UniqueConstraint("user_id", "date", "source", name="analytics_user_date_source"),)
    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    date: Mapped[date] = mapped_column(Date, index=True)
    metrics: Mapped[dict[str, Any]] = mapped_column(JSONB)
    source: Mapped[str] = mapped_column(String(30), default="computed")


class PracticeSign(TimestampMixin, Base):
    __tablename__ = "practice_signs"
    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    sign_id: Mapped[str] = mapped_column(String(100), unique=True, index=True)
    expected_text: Mapped[str] = mapped_column(String(200))
    language_code: Mapped[str] = mapped_column(String(20))
    difficulty: Mapped[str] = mapped_column(String(30), default="Easy")
    metadata_json: Mapped[dict[str, Any]] = mapped_column("metadata", JSONB, default=dict)
    active: Mapped[bool] = mapped_column(Boolean, default=True)


class PracticeModeData(Base):
    __tablename__ = "practice_mode_data"
    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    sign_id: Mapped[str] = mapped_column(String(100), index=True)
    expected_text: Mapped[str] = mapped_column(String(200))
    detected_text: Mapped[str | None] = mapped_column(String(200))
    score: Mapped[float | None] = mapped_column(Float)
    confidence: Mapped[float | None] = mapped_column(Float)
    source: Mapped[str] = mapped_column(String(30), default="live")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class FeedbackReport(TimestampMixin, Base):
    __tablename__ = "feedback_reports"
    __table_args__ = (
        CheckConstraint("type IN ('bug', 'feedback')", name="type"),
        CheckConstraint("status IN ('open', 'reviewed', 'resolved', 'dismissed')", name="status"),
    )
    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    report_id: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    type: Mapped[str] = mapped_column(String(20))
    message: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(20), default="open")
    admin_notes: Mapped[str | None] = mapped_column(Text)
    app_version: Mapped[str | None] = mapped_column(String(40))
    device_info: Mapped[dict[str, Any] | None] = mapped_column(JSONB)


class AdminConfig(TimestampMixin, Base):
    __tablename__ = "admin_config"
    __table_args__ = (CheckConstraint("system_status IN ('on', 'off')", name="system_status"),)
    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    singleton_key: Mapped[str] = mapped_column(String(20), unique=True, default="default")
    system_status: Mapped[str] = mapped_column(String(10), default="off")
    active_model_id: Mapped[UUID | None] = mapped_column(ForeignKey("models.id", ondelete="SET NULL"))
    service_toggles: Mapped[dict[str, bool]] = mapped_column(JSONB, default=dict)
    updated_by: Mapped[UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))


class Alert(Base):
    __tablename__ = "alerts"
    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    title: Mapped[str] = mapped_column(String(120))
    message: Mapped[str] = mapped_column(String(500))
    type: Mapped[str] = mapped_column(String(20), default="info")
    is_read: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class FirmwareRelease(TimestampMixin, Base):
    __tablename__ = "firmware_releases"
    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    device_model: Mapped[str] = mapped_column(String(100), index=True)
    version: Mapped[str] = mapped_column(String(50))
    release_notes: Mapped[str | None] = mapped_column(Text)
    package_url: Mapped[str | None] = mapped_column(String(500))
    active: Mapped[bool] = mapped_column(Boolean, default=True)


class AuditLog(Base):
    __tablename__ = "audit_logs"
    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    actor_user_id: Mapped[UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), index=True)
    action: Mapped[str] = mapped_column(String(100), index=True)
    target_type: Mapped[str | None] = mapped_column(String(80))
    target_id: Mapped[str | None] = mapped_column(String(128))
    details: Mapped[dict[str, Any]] = mapped_column(JSONB, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
