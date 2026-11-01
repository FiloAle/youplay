import { useCallback, useLayoutEffect, useRef } from "react";

/** Returns a function whose identity never changes, but that always runs the latest `fn`. */
export function useStableCallback<Args extends unknown[], Result>(
	fn: (...args: Args) => Result,
): (...args: Args) => Result {
	const latest = useRef(fn);

	useLayoutEffect(() => {
		latest.current = fn;
	});

	return useCallback((...args: Args) => latest.current(...args), []);
}
