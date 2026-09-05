"use client";

import { useEffect, useRef } from "react";

export function useTemplateEditorLeaveGuard(isDirty: boolean, isBusy: boolean, message: string) {
  const navigationAllowed = useRef(false);

  useEffect(() => {
    if (!isDirty && !isBusy) return;
    function beforeUnload(event: BeforeUnloadEvent) {
      if (navigationAllowed.current) return;
      event.preventDefault();
      event.returnValue = "";
    }
    function onLinkClick(event: MouseEvent) {
      if (
        navigationAllowed.current ||
        event.defaultPrevented ||
        event.button !== 0 ||
        event.metaKey ||
        event.ctrlKey ||
        event.shiftKey ||
        event.altKey
      )
        return;
      const anchor = (event.target as HTMLElement).closest?.("a[href]");
      if (
        !(anchor instanceof HTMLAnchorElement) ||
        anchor.target === "_blank" ||
        anchor.hasAttribute("download")
      )
        return;
      const destination = new URL(anchor.href);
      if (destination.pathname === location.pathname && destination.search === location.search)
        return;
      if (isBusy || !window.confirm(message)) {
        event.preventDefault();
        event.stopPropagation();
      } else {
        navigationAllowed.current = true;
      }
    }
    window.addEventListener("beforeunload", beforeUnload);
    document.addEventListener("click", onLinkClick, true);
    return () => {
      window.removeEventListener("beforeunload", beforeUnload);
      document.removeEventListener("click", onLinkClick, true);
    };
  }, [isDirty, isBusy, message]);

  return {
    allowNavigation: () => {
      navigationAllowed.current = true;
    },
    confirmDiscard: () => !isBusy && (!isDirty || window.confirm(message)),
  };
}
