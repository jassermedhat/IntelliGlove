export type AdminConfig = {
  systemStatus: 'on' | 'off';
  activeModelId: string | null;
  serviceToggles: Record<string, boolean>;
  updatedAt: string;
};

export type MlModel = {
  id: string;
  modelId: string;
  name: string;
  filePath: string | null;
  labelsPath: string | null;
  version: string | null;
  status: 'available' | 'invalid' | 'archived';
  isActive: boolean;
  metadata: Record<string, unknown> | null;
  createdAt: string;
  updatedAt: string;
};

export type Report = {
  id: string;
  reportId: string;
  userId: string;
  type: 'bug' | 'feedback';
  message: string;
  status: 'open' | 'reviewed' | 'resolved' | 'dismissed';
  adminNotes: string | null;
  appVersion: string | null;
  deviceInfo: Record<string, unknown> | null;
  createdAt: string;
  updatedAt: string;
};

export type AuditLog = {
  id: string;
  actorUserId: string | null;
  action: string;
  targetType: string | null;
  targetId: string | null;
  details: Record<string, unknown>;
  createdAt: string;
};

export type UserProfile = {
  id: string;
  firebaseUid: string;
  email: string;
  name: string;
  role: 'user' | 'admin';
  emailVerified: boolean;
  photoUrl: string | null;
  status: 'active' | 'disabled';
  createdAt: string;
  updatedAt: string;
  lastLoginAt: string | null;
};

export type ActiveTranslationSession = {
  sessionId: string;
  userId: string;
  userEmail: string;
  userName: string;
  startedAt: string;
  totalReadings: number;
};

/** Minimal user record returned by GET /admin/users (Issue 1). */
export type AdminUserSummary = {
  id: string;
  email: string;
  name: string;
  role: 'user' | 'admin';
};

export type DemoGloveState = {
  connected: boolean;
  device: {
    id: string;
    deviceName: string;
    hardwareId: string | null;
    connectionStatus: string;
    firmwareVersion: string | null;
    batteryLevel: number | null;
    signalStrength: number | null;
    connectedAt: string | null;
    lastSeen: string | null;
  } | null;
};
