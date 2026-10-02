import { EdvoraLoader, Icon } from './Brand';

export function LoadingState({ label = 'Loading…' }) {
  return (
    <div className="data-state data-state-loading">
      <EdvoraLoader label={label} size={42} />
    </div>
  );
}

export function ErrorState({ message, onRetry }) {
  return (
    <div className="data-state error-state">
      <div className="error-icon-box">
        <Icon name="close" size={20} />
      </div>
      <strong>Something went wrong</strong>
      <p>{message}</p>
      {onRetry && (
        <button className="app-button primary" onClick={onRetry}>
          Try again
        </button>
      )}
    </div>
  );
}

export function EmptyState({ title = 'Nothing here yet', description, action }) {
  return (
    <div className="data-state empty-state">
      <strong>{title}</strong>
      {description && <p>{description}</p>}
      {action}
    </div>
  );
}
