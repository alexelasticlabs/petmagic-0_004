import { describe, expect, it } from "vitest";

import {
  isLocalOrPrivateAdminRemoteHost,
  isUnsafeAdminMediaHost,
} from "@/lib/admin-unsafe-remote-host";

describe("admin unsafe remote host detection", () => {
  it("blocks IPv4-mapped IPv6 loopback and private hosts", () => {
    expect(isLocalOrPrivateAdminRemoteHost("[::ffff:7f00:1]")).toBe(true);
    expect(isLocalOrPrivateAdminRemoteHost("::ffff:7f00:1")).toBe(true);
    expect(isLocalOrPrivateAdminRemoteHost("::ffff:a00:5")).toBe(true);
    expect(isLocalOrPrivateAdminRemoteHost("::ffff:ac10:1")).toBe(true);
    expect(isLocalOrPrivateAdminRemoteHost("::ffff:c0a8:101")).toBe(true);
  });

  it("does not block public IPv4-mapped IPv6 hosts", () => {
    expect(isLocalOrPrivateAdminRemoteHost("::ffff:0808:0808")).toBe(false);
    expect(isUnsafeAdminMediaHost("::ffff:0808:0808")).toBe(false);
  });
});
