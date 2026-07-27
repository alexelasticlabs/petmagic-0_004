export function getUserSupportTicketsPlaceholderData<T>(
  previousData: T | undefined,
  previousQueryKey: readonly unknown[] | undefined,
  userId: string
): T | undefined {
  return previousQueryKey?.[2] === userId ? previousData : undefined;
}
