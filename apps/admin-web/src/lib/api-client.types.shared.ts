export type OffsetPagedResponse<T> = {
  items: T[];

  skip: number;

  take: number;

  hasMore: boolean;

  totalCount?: number | null;
};
