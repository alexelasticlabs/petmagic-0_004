import { UserDetailPage } from "@/components/users/user-detail-page";
import { isLocale, type Locale } from "@/lib/i18n";
import { notFound } from "next/navigation";

type UserDetailRouteProps = {
  params: Promise<{
    locale: string;
    userId: string;
  }>;
};

export default async function UserDetailRoute({ params }: UserDetailRouteProps) {
  const resolved = await params;
  if (!isLocale(resolved.locale)) {
    notFound();
  }

  return <UserDetailPage locale={resolved.locale as Locale} userId={resolved.userId} />;
}
