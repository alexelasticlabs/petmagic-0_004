export const economyWorkspaces = ["overview", "catalog", "subscriptions", "payments"] as const;

export type EconomyWorkspace = (typeof economyWorkspaces)[number];
