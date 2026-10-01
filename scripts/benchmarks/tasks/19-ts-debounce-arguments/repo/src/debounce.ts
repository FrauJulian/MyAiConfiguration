export function debounce<T extends unknown[]>(fn: (...args: T) => void, wait: number): (...args: T) => void {
  let timer: ReturnType<typeof setTimeout> | undefined;
  let pending: T | undefined;
  return (...args: T) => {
    if (pending === undefined) {
      pending = args;
    }
    clearTimeout(timer);
    timer = setTimeout(() => {
      const call = pending as T;
      pending = undefined;
      fn(...call);
    }, wait);
  };
}
