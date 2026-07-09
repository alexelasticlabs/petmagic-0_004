import { describe, expect, it } from "vitest";

import {
  isLocalOrPrivateAdminRemoteHost,
  isUnsafeAdminMediaHost,
} from "@/lib/admin-unsafe-remote-host";

describe("admin unsafe remote host detection", () => {
  it("blocks local, private, reserved, and placeholder hosts", () => {
    for (const host of [
      "localhost",
      "media.localhost",
      "0.0.0.1",
      "10.0.0.5",
      "100.64.0.1",
      "169.254.169.254",
      "172.16.0.1",
      "192.168.1.1",
      "224.0.0.1",
      "2130706433",
      "0x7f000001",
      "0177.0.0.1",
      "127.1",
      "127.0.1",
      "0300.0250.0001.0001",
      "[0:0:0:0:0:0:0:0]",
      "[0:0:0:0:0:0:0:1]",
      "[fe90::1]",
      "[fec0::1]",
      "[ff02::1]",
    ]) {
      expect(isLocalOrPrivateAdminRemoteHost(host), host).toBe(true);
    }

    expect(isUnsafeAdminMediaHost("assets.example.com")).toBe(true);
  });

  it("blocks IPv4-mapped IPv6 loopback and private hosts", () => {
    expect(isLocalOrPrivateAdminRemoteHost("[::ffff:7f00:1]")).toBe(true);
    expect(isLocalOrPrivateAdminRemoteHost("::ffff:7f00:1")).toBe(true);
    expect(isLocalOrPrivateAdminRemoteHost("::127.0.0.1")).toBe(true);
    expect(isLocalOrPrivateAdminRemoteHost("::7f00:1")).toBe(true);
    expect(isLocalOrPrivateAdminRemoteHost("0:0:0:0:0:ffff:7f00:1")).toBe(true);
    expect(isLocalOrPrivateAdminRemoteHost("0:0:0:0:0:ffff:127.0.0.1")).toBe(true);
    expect(isLocalOrPrivateAdminRemoteHost("0:0:0:0:0:0:7f00:1")).toBe(true);
    expect(isLocalOrPrivateAdminRemoteHost("0:0:0:0:0:0:127.0.0.1")).toBe(true);
    expect(isLocalOrPrivateAdminRemoteHost("::ffff:a00:5")).toBe(true);
    expect(isLocalOrPrivateAdminRemoteHost("::ffff:ac10:1")).toBe(true);
    expect(isLocalOrPrivateAdminRemoteHost("::ffff:c0a8:101")).toBe(true);
  });

  it("does not block public IPv4-mapped IPv6 hosts", () => {
    expect(isLocalOrPrivateAdminRemoteHost("134744072")).toBe(false);
    expect(isLocalOrPrivateAdminRemoteHost("0x08080808")).toBe(false);
    expect(isLocalOrPrivateAdminRemoteHost("8.8.8.8")).toBe(false);
    expect(isLocalOrPrivateAdminRemoteHost("::ffff:0808:0808")).toBe(false);
    expect(isLocalOrPrivateAdminRemoteHost("::8.8.8.8")).toBe(false);
    expect(isLocalOrPrivateAdminRemoteHost("::0808:0808")).toBe(false);
    expect(isLocalOrPrivateAdminRemoteHost("0:0:0:0:0:ffff:0808:0808")).toBe(false);
    expect(isLocalOrPrivateAdminRemoteHost("0:0:0:0:0:0:0808:0808")).toBe(false);
    expect(isUnsafeAdminMediaHost("::ffff:0808:0808")).toBe(false);
  });
});
