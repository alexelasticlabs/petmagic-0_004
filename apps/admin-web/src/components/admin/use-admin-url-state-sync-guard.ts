"use client";

import { useCallback, useEffect, useRef } from "react";

type UseAdminUrlStateSyncGuardOptions = {
  currentSearch: string;
  applyUrlState: (searchParams: URLSearchParams) => void;
  suspended?: boolean;
};

/**
 * Coordinates bidirectional URL state without allowing the local write effect
 * to overwrite a same-route browser navigation before React applies it.
 */
export function useAdminUrlStateSyncGuard({
  currentSearch,
  applyUrlState,
  suspended = false,
}: UseAdminUrlStateSyncGuardOptions) {
  const applyUrlStateRef = useRef(applyUrlState);
  const applyingUrlStateRef = useRef(false);
  const lastWrittenSearchRef = useRef<string | null>(null);

  useEffect(() => {
    applyUrlStateRef.current = applyUrlState;
  }, [applyUrlState]);

  useEffect(() => {
    if (suspended) {
      return;
    }

    if (lastWrittenSearchRef.current === currentSearch) {
      lastWrittenSearchRef.current = null;
      return;
    }

    applyingUrlStateRef.current = true;
    applyUrlStateRef.current(new URLSearchParams(currentSearch));
  }, [currentSearch, suspended]);

  const consumeUrlStateApplication = useCallback((keepApplying = false) => {
    if (!applyingUrlStateRef.current) {
      return false;
    }

    if (!keepApplying) {
      applyingUrlStateRef.current = false;
    }
    return true;
  }, []);

  const markUrlStateWritten = useCallback((nextSearch: string) => {
    lastWrittenSearchRef.current = nextSearch;
  }, []);

  return { consumeUrlStateApplication, markUrlStateWritten };
}
