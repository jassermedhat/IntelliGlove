export function Spinner({ size = 36 }: { size?: number }) {
  return (
    <div
      role="status"
      aria-label="Loading"
      style={{
        width: size,
        height: size,
        border: '3px solid #1e3d52',
        borderTopColor: '#69e0d1',
        borderRadius: '50%',
        animation: 'spin .75s linear infinite',
        flexShrink: 0,
      }}
    />
  );
}

export function PageSpinner() {
  return (
    <div className="page-center">
      <Spinner size={48} />
    </div>
  );
}
