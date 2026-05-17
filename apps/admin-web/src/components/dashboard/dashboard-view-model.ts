import { type Locale } from "@/lib/i18n";

export type DashboardActivityType = "new" | "update" | "register" | "cancel";
export type DashboardStatIcon = "people" | "cart" | "dollar" | "trendUp";
export type DashboardOrderStatusType = "new" | "processing" | "delivered" | "cancelled";

export type DashboardStatItem = {
  label: string;
  value: string;
  delta: string;
  subtext: string;
  accentColor: string;
  icon: DashboardStatIcon;
};

export type DashboardOrderItem = {
  id: string;
  user: string;
  amount: string;
  status: string;
  statusType: DashboardOrderStatusType;
};

export type DashboardActivityItem = {
  type: DashboardActivityType;
  text: string;
  time: string;
};

export type DashboardUserDistributionItem = {
  color: string;
  label: string;
  pct: string;
  count: string;
};

export function buildDashboardViewModel(locale: Locale) {
  const isRu = locale === "ru";

  return {
    hero: {
      eyebrow: "Control center",
      title: isRu ? "Обзор админки" : "Admin Overview",
      description: isRu
        ? "Ключевые метрики, активность и монетизация в одном темпе и с тем же визуальным ритмом, что и остальные экраны админки."
        : "Key metrics, activity, and monetization with the same pacing and visual rhythm as the rest of the admin.",
      badge: isRu ? "Последние 7 дней" : "Last 7 days",
      metaItems: [
        isRu ? "4 KPI-карточки" : "4 KPI cards",
        isRu ? "2 аналитических блока" : "2 analytics blocks",
        isRu ? "Живой мониторинг" : "Live monitoring",
      ],
    },
    revenueChart: {
      title: isRu ? "Динамика выручки" : "Revenue dynamics",
      description: isRu ? "Последние семь дней по активным заказам" : "Last seven days across active orders",
      rangeLabel: isRu ? "Неделя" : "Week",
      ariaLabel: isRu ? "График выручки" : "Revenue chart",
      xLabels: isRu
        ? ["20 мая", "21 мая", "22 мая", "23 мая", "24 мая", "25 мая", "26 мая"]
        : ["May 20", "May 21", "May 22", "May 23", "May 24", "May 25", "May 26"],
    },
    ordersSection: {
      title: isRu ? "Последние заказы" : "Recent orders",
      description: isRu ? "Свежие события монетизации" : "Latest monetization events",
      viewAllLabel: isRu ? "Смотреть все" : "View all",
      headers: {
        order: isRu ? "Заказ" : "Order",
        user: isRu ? "Пользователь" : "User",
        amount: isRu ? "Сумма" : "Amount",
        status: isRu ? "Статус" : "Status",
      },
    },
    distributionSection: {
      title: isRu ? "Распределение пользователей" : "User distribution",
      totalLabel: isRu ? "Всего" : "Total",
    },
    activitySection: {
      title: isRu ? "Активность" : "Activity",
      description: isRu ? "Последние действия в системе" : "Recent system actions",
    },
    stats: [
      {
        label: isRu ? "Пользователи" : "Users",
        value: "1 256",
        delta: "+12.5%",
        subtext: isRu ? "к прошлой неделе" : "compared to last week",
        icon: "people",
        accentColor: "#2dd4bf",
      },
      {
        label: isRu ? "Заказы" : "Orders",
        value: "3 846",
        delta: "+8.1%",
        subtext: isRu ? "к прошлой неделе" : "compared to last week",
        icon: "cart",
        accentColor: "#22c55e",
      },
      {
        label: isRu ? "Выручка" : "Revenue",
        value: "$24 980",
        delta: "+15.3%",
        subtext: isRu ? "к прошлой неделе" : "compared to last week",
        icon: "dollar",
        accentColor: "#facc15",
      },
      {
        label: isRu ? "Конверсия" : "Conversion",
        value: "4.74%",
        delta: "+6.2%",
        subtext: isRu ? "к прошлой неделе" : "compared to last week",
        icon: "trendUp",
        accentColor: "#f472b6",
      },
    ] satisfies DashboardStatItem[],
    orders: [
      { id: "#10245", user: isRu ? "Иван Петров" : "Ivan Petrov", amount: "$152.00", status: isRu ? "Новый" : "New", statusType: "new" },
      { id: "#10244", user: isRu ? "Мария Смирнова" : "Maria Smirnova", amount: "$89.90", status: isRu ? "В обработке" : "Processing", statusType: "processing" },
      { id: "#10243", user: isRu ? "Алексей Иванов" : "Alexei Ivanov", amount: "$129.50", status: isRu ? "Доставлен" : "Delivered", statusType: "delivered" },
      { id: "#10242", user: isRu ? "Ольга Кузнецова" : "Olga Kuznetsova", amount: "$75.00", status: isRu ? "Отменён" : "Cancelled", statusType: "cancelled" },
      { id: "#10241", user: isRu ? "Дмитрий Соколов" : "Dmitry Sokolov", amount: "$199.99", status: isRu ? "Доставлен" : "Delivered", statusType: "delivered" },
    ] satisfies DashboardOrderItem[],
    activities: [
      { type: "new", text: isRu ? "Иван Петров создал новый заказ #10245" : "Ivan Petrov created new order #10245", time: isRu ? "2 мин. назад" : "2 min ago" },
      { type: "update", text: isRu ? "Мария Смирнова обновила статус заказа #10244" : "Maria Smirnova updated order #10244 status", time: isRu ? "15 мин. назад" : "15 min ago" },
      { type: "register", text: isRu ? "Алексей Иванов зарегистрировался в системе" : "Alexei Ivanov registered in the system", time: isRu ? "1 час назад" : "1 hour ago" },
      { type: "cancel", text: isRu ? "Ольга Кузнецова отменила заказ #10242" : "Olga Kuznetsova cancelled order #10242", time: isRu ? "2 часа назад" : "2 hours ago" },
    ] satisfies DashboardActivityItem[],
    userDistribution: [
      { color: "#22c55e", label: isRu ? "Администраторы" : "Administrators", pct: "12%", count: "151" },
      { color: "#059669", label: isRu ? "Менеджеры" : "Managers", pct: "28%", count: "352" },
      { color: "#1f5d3c", label: isRu ? "Пользователи" : "Users", pct: "60%", count: "753" },
    ] satisfies DashboardUserDistributionItem[],
  };
}
