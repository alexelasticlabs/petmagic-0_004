export type LegalDocumentSection = {

  heading: string;

  paragraphs: string[];

};


export type LegalDocument = {

  kind: string;

  title: string;

  version: string;

  publishedAtUtc: string;

  summary: string;

  sections: LegalDocumentSection[];

};


export type LegalDocumentsResponse = {

  termsOfUse: LegalDocument;

  privacyPolicy: LegalDocument;

};


export type LegalAcceptanceStatus = {

  termsOfUseAccepted: boolean;

  termsOfUseAcceptedVersion?: string | null;

  termsOfUseAcceptedAtUtc?: string | null;

  privacyPolicyAccepted: boolean;

  privacyPolicyAcceptedVersion?: string | null;

  privacyPolicyAcceptedAtUtc?: string | null;

  currentTermsOfUseVersion: string;

  currentPrivacyPolicyVersion: string;

  requiresAcceptance: boolean;

};


export type AcceptLegalDocumentsCommand = {

  termsOfUseVersion: string;

  privacyPolicyVersion: string;

};


export type UserProfile = {

  userId: string;

  email: string;

  displayName?: string;

  isPremium: boolean;

  emailConfirmed: boolean;

  roles: string[];

  accountStatus?: string;

  termsOfUseAccepted?: boolean;

  privacyPolicyAccepted?: boolean;

  legalAcceptance?: LegalAcceptanceStatus;

  avatar?: UserAvatar | null;

};


export type UserAvatar = {

  url: string;

  fileName: string;

  contentType: string;

  fileSizeBytes?: number | null;

  updatedAtUtc?: string | null;

};


export type AuthSession = {

  accessToken?: string;

  refreshToken?: string;

  expiresAtUtc: string;

  user: UserProfile;

};


