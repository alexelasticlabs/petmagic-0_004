export type FeedbackType =

  | "GenerationResult"

  | "GenerationFailure"

  | "BugReport"

  | "FeatureRequest"

  | "PaymentIssue"

  | "General";


export type FeedbackStatus = "New" | "InReview" | "Resolved" | "Dismissed";


export type FeedbackPriority = "Low" | "Medium" | "High" | "Critical";


export type AdminFeedbackListItem = {

  id: string;

  userId?: string | null;

  type: FeedbackType | string;

  category: string;

  rating?: number | null;

  generationId?: string | null;

  templateId?: string | null;

  templateTitle?: string | null;

  petId?: string | null;

  sourceScreen: string;

  platform?: string | null;

  status: FeedbackStatus | string;

  priority: FeedbackPriority | string;

  message?: string | null;

  previewUrl?: string | null;

  createdAtUtc: string;

};


export type AdminFeedbackPage = {

  items: AdminFeedbackListItem[];

  totalCount: number;

  skip: number;

  take: number;

  hasMore: boolean;

  generatedAtUtc: string;

};


export type AdminFeedbackGenerationContext = {

  generationId: string;

  userId: string;

  templateId: string;

  templateTitle: string;

  petId?: string | null;

  inputPreviewUrl?: string | null;

  resultPreviewUrl?: string | null;

  providerName?: string | null;

  errorCode?: string | null;

  creditsCharged: number;

  chargedAtUtc?: string | null;

  refundedAtUtc?: string | null;

};


export type CreditRefund = {

  id: string;

  userId: string;

  feedbackId?: string | null;

  generationId?: string | null;

  amount: number;

  reason: string;

  adminId: string;

  createdAtUtc: string;

};


export type AdminFeedbackDetails = {

  id: string;

  userId?: string | null;

  userEmail?: string | null;

  userPlan?: string | null;

  userCredits?: number | null;

  type: FeedbackType | string;

  category: string;

  rating?: number | null;

  message?: string | null;

  sourceScreen: string;

  appVersion?: string | null;

  platform?: string | null;

  deviceModel?: string | null;

  locale?: string | null;

  errorCode?: string | null;

  providerName?: string | null;

  status: FeedbackStatus | string;

  priority: FeedbackPriority | string;

  createdAtUtc: string;

  reviewedAtUtc?: string | null;

  reviewedByAdminId?: string | null;

  adminNote?: string | null;

  generation?: AdminFeedbackGenerationContext | null;

  canRefund: boolean;

  refund?: CreditRefund | null;

};


export type AdminFeedbackQuery = {

  status?: FeedbackStatus | "All";

  priority?: FeedbackPriority | "All";

  type?: FeedbackType | "All";

  category?: string;

  generationId?: string;

  templateId?: string;

  platform?: string;

  fromUtc?: string;

  toUtc?: string;

  userId?: string;

  skip?: number;

  take?: number;

};


export type UpdateFeedbackAdminPayload = {

  status?: FeedbackStatus;

  priority?: FeedbackPriority;

  adminNote?: string;

};


export type RefundFeedbackCreditsPayload = {

  amount?: number;

  reason?: string;

};


export type TemplateFeedbackIssue = {

  category: string;

  count: number;

};


export type TemplateFeedbackSummary = {

  templateId: string;

  positiveCount: number;

  neutralCount: number;

  negativeCount: number;

  positiveRate: number;

  neutralRate: number;

  negativeRate: number;

  topIssues: TemplateFeedbackIssue[];

  hasNegativeWarning: boolean;

};
