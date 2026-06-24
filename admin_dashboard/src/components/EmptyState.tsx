export function EmptyState({ icon, title, message }: { icon?: string; title: string; message?: string }) {
  return (
    <div className="empty-state">
      {icon && <div className="empty-icon">{icon}</div>}
      <strong>{title}</strong>
      {message && <p>{message}</p>}
    </div>
  );
}
